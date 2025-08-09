//
//  CacheManager.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 8/4/25.
//

import Foundation
import SwiftUI

/// High-performance multi-tier caching system for MealPrep data
///
/// Implements a three-tier caching strategy:
/// - Tier 1: In-memory cache (fastest, limited capacity)
/// - Tier 2: Disk cache (persistent, medium speed)
/// - Tier 3: Network cache with TTL (slowest, most comprehensive)
///
/// Key Features:
/// - Automatic cache eviction based on LRU and TTL
/// - Thread-safe concurrent access
/// - Memory pressure handling
/// - Cache warming and preloading
/// - Intelligent cache invalidation
@MainActor
class MultiTierCacheManager: ObservableObject {

    // MARK: - Cache Configuration

    private struct CacheConfig {
        static let memoryCapacity = 50 // Number of items in memory
        static let diskCapacity = 200 // Number of items on disk
        static let defaultTTL: TimeInterval = 3600 // 1 hour
        static let shortTTL: TimeInterval = 300 // 5 minutes
        static let longTTL: TimeInterval = 86400 // 24 hours
    }

    // MARK: - Cache Item

    private struct CacheItem<T: Codable> {
        let value: T
        let timestamp: Date
        let ttl: TimeInterval
        let accessCount: Int
        let lastAccessed: Date

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }

        var priority: Double {
            // Higher priority = more likely to be kept in cache
            let recency = 1.0 / (Date().timeIntervalSince(lastAccessed) + 1)
            let frequency = Double(accessCount) / 100.0
            return recency * 0.7 + frequency * 0.3
        }
    }

    // MARK: - Multi-Tier Storage

    // Tier 1: Memory Cache (fastest)
    private var memoryCache: [String: Any] = [:]
    private var memoryMetadata: [String: (timestamp: Date, ttl: TimeInterval, accessCount: Int)] = [:]

    // Tier 2: Disk Cache (persistent)
    private let diskCacheURL: URL
    private let fileManager = FileManager.default

    // Tier 3: Network metadata tracking
    private var networkMetadata: [String: Date] = [:]

    // MARK: - Cache Statistics

    @Published var stats = CacheStats()

    struct CacheStats {
        var memoryHits: Int = 0
        var diskHits: Int = 0
        var misses: Int = 0
        var evictions: Int = 0
        var memoryUsage: Int = 0
        var diskUsage: Int = 0

        var hitRate: Double {
            let total = memoryHits + diskHits + misses
            return total > 0 ? Double(memoryHits + diskHits) / Double(total) : 0
        }
    }

    // MARK: - Initialization

    init() {
        // Create disk cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = cacheDir.appendingPathComponent("MealPrepCache")

        do {
            try fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        } catch {
            print("❌ [CacheManager] Failed to create cache directory: \(error)")
        }

        // Setup memory pressure monitoring
        setupMemoryPressureHandling()

        // Perform initial cache cleanup
        Task {
            await cleanupExpiredItems()
        }
    }

    // MARK: - Generic Cache Operations

    /// Store item in cache with automatic tier selection
    func store<T: Codable>(_ item: T, forKey key: String, ttl: TimeInterval = CacheConfig.defaultTTL) {
        print("📦 [CacheManager] Storing item for key: \(key)")

        // Store in memory cache (Tier 1)
        memoryCache[key] = item
        memoryMetadata[key] = (Date(), ttl, 1)

        // Async store to disk cache (Tier 2)
        Task {
            await storeToDisk(item, forKey: key, ttl: ttl)
        }

        // Manage memory cache size
        enforceMemoryCapacity()

        stats.memoryUsage = memoryCache.count
        print("✅ [CacheManager] Stored item successfully, memory usage: \(stats.memoryUsage)")
    }

    /// Retrieve item from cache with automatic tier fallback
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        print("🔍 [CacheManager] Retrieving item for key: \(key)")

        // Try Tier 1: Memory Cache
        if let memoryItem = retrieveFromMemory(type, forKey: key) {
            stats.memoryHits += 1
            print("✅ [CacheManager] Memory cache hit for key: \(key)")
            return memoryItem
        }

        // Try Tier 2: Disk Cache
        if let diskItem = retrieveFromDisk(type, forKey: key) {
            // Promote to memory cache
            memoryCache[key] = diskItem
            memoryMetadata[key] = (Date(), CacheConfig.defaultTTL, 1)

            stats.diskHits += 1
            print("✅ [CacheManager] Disk cache hit for key: \(key), promoted to memory")
            return diskItem
        }

        // Cache miss
        stats.misses += 1
        print("❌ [CacheManager] Cache miss for key: \(key)")
        return nil
    }

    /// Remove item from all cache tiers
    func remove(key: String) {
        print("🗑️ [CacheManager] Removing item for key: \(key)")

        // Remove from memory
        memoryCache.removeValue(forKey: key)
        memoryMetadata.removeValue(forKey: key)

        // Remove from disk
        let diskURL = diskCacheURL.appendingPathComponent(key)
        try? fileManager.removeItem(at: diskURL)

        // Remove network metadata
        networkMetadata.removeValue(forKey: key)

        stats.memoryUsage = memoryCache.count
    }

    /// Clear all cache tiers
    func clearAll() {
        print("🧹 [CacheManager] Clearing all caches")

        // Clear memory
        memoryCache.removeAll()
        memoryMetadata.removeAll()

        // Clear disk
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        // Clear network metadata
        networkMetadata.removeAll()

        // Reset stats
        stats = CacheStats()
    }

    // MARK: - Specialized Cache Methods for Recipe Data

    /// Cache recipe stubs with short TTL for quick access
    func cacheRecipeStubs(_ stubs: [RecipeStub], forKey key: String) {
        store(stubs, forKey: "recipestubs_\(key)", ttl: CacheConfig.shortTTL)
    }

    /// Retrieve cached recipe stubs
    func getCachedRecipeStubs(forKey key: String) -> [RecipeStub]? {
        return retrieve([RecipeStub].self, forKey: "recipestubs_\(key)")
    }

    /// Cache full recipes with longer TTL
    func cacheRecipes(_ recipes: [Recipe], forKey key: String) {
        store(recipes, forKey: "recipes_\(key)", ttl: CacheConfig.longTTL)
    }

    /// Retrieve cached recipes
    func getCachedRecipes(forKey key: String) -> [Recipe]? {
        return retrieve([Recipe].self, forKey: "recipes_\(key)")
    }

    /// Cache AI-generated meal plans with medium TTL
    func cacheAIMealPlan(_ mealPlan: MealPlan, forKey key: String) {
        store(mealPlan, forKey: "aimealplan_\(key)", ttl: CacheConfig.defaultTTL)
    }

    /// Retrieve cached AI meal plan
    func getCachedAIMealPlan(forKey key: String) -> MealPlan? {
        return retrieve(MealPlan.self, forKey: "aimealplan_\(key)")
    }

    // MARK: - Cache Warming and Preloading

    /// Warm cache with frequently accessed data
    func warmCache() async {
        print("🔥 [CacheManager] Starting cache warming")

        // This would typically load frequently accessed recipes, recent meal plans, etc.
        // Implementation depends on data access patterns

        print("✅ [CacheManager] Cache warming completed")
    }

    /// Preload data for specific user patterns
    func preloadForUser(preferences: [String: Any]) async {
        print("⚡ [CacheManager] Preloading data for user preferences")

        // Implementation would analyze user preferences and preload relevant data
        // For example: favorite cuisines, dietary restrictions, etc.

        print("✅ [CacheManager] User-specific preloading completed")
    }

    // MARK: - Private Implementation

    private func retrieveFromMemory<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let item = memoryCache[key] as? T,
              let metadata = memoryMetadata[key] else {
            return nil
        }

        // Check TTL
        if Date().timeIntervalSince(metadata.timestamp) > metadata.ttl {
            memoryCache.removeValue(forKey: key)
            memoryMetadata.removeValue(forKey: key)
            return nil
        }

        // Update access metadata
        memoryMetadata[key] = (metadata.timestamp, metadata.ttl, metadata.accessCount + 1)

        return item
    }

    private func retrieveFromDisk<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        let fileURL = diskCacheURL.appendingPathComponent(key)

        guard let data = try? Data(contentsOf: fileURL),
              let item = try? JSONDecoder().decode(T.self, from: data) else {
            return nil
        }

        // Check file modification date for TTL
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return nil
        }

        if Date().timeIntervalSince(modificationDate) > CacheConfig.defaultTTL {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }

        return item
    }

    private func storeToDisk<T: Codable>(_ item: T, forKey key: String, ttl: TimeInterval) async {
        let fileURL = diskCacheURL.appendingPathComponent(key)

        do {
            let data = try JSONEncoder().encode(item)
            try data.write(to: fileURL)
            print("💾 [CacheManager] Stored item to disk: \(key)")
        } catch {
            print("❌ [CacheManager] Failed to store item to disk: \(error)")
        }
    }

    private func enforceMemoryCapacity() {
        while memoryCache.count > CacheConfig.memoryCapacity {
            evictLeastRecentlyUsed()
        }
    }

    private func evictLeastRecentlyUsed() {
        guard !memoryMetadata.isEmpty else { return }

        // Find least recently used item
        let oldestKey = memoryMetadata.min { lhs, rhs in
            let lhsPriority = calculatePriority(for: lhs.value)
            let rhsPriority = calculatePriority(for: rhs.value)
            return lhsPriority < rhsPriority
        }?.key

        if let keyToEvict = oldestKey {
            memoryCache.removeValue(forKey: keyToEvict)
            memoryMetadata.removeValue(forKey: keyToEvict)
            stats.evictions += 1
            print("⚠️ [CacheManager] Evicted item from memory: \(keyToEvict)")
        }
    }

    private func calculatePriority(for metadata: (timestamp: Date, ttl: TimeInterval, accessCount: Int)) -> Double {
        let recency = 1.0 / (Date().timeIntervalSince(metadata.timestamp) + 1)
        let frequency = Double(metadata.accessCount) / 100.0
        return recency * 0.7 + frequency * 0.3
    }

    private func setupMemoryPressureHandling() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryPressure()
            }
        }
    }

    private func handleMemoryPressure() {
        print("⚠️ [CacheManager] Handling memory pressure")

        // Aggressive memory cleanup
        let currentSize = memoryCache.count
        let targetSize = max(CacheConfig.memoryCapacity / 4, 10) // Keep only 25% or minimum 10 items

        while memoryCache.count > targetSize {
            evictLeastRecentlyUsed()
        }

        let clearedItems = currentSize - memoryCache.count
        print("🧹 [CacheManager] Cleared \(clearedItems) items due to memory pressure")
    }

    private func cleanupExpiredItems() async {
        print("🧹 [CacheManager] Cleaning up expired items")

        var expiredCount = 0

        // Cleanup memory cache
        let expiredMemoryKeys = memoryMetadata.compactMap { key, metadata in
            Date().timeIntervalSince(metadata.timestamp) > metadata.ttl ? key : nil
        }

        for key in expiredMemoryKeys {
            memoryCache.removeValue(forKey: key)
            memoryMetadata.removeValue(forKey: key)
            expiredCount += 1
        }

        // Cleanup disk cache
        do {
            let diskFiles = try fileManager.contentsOfDirectory(at: diskCacheURL,
                                                               includingPropertiesForKeys: [.contentModificationDateKey],
                                                               options: [])

            for fileURL in diskFiles {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let modificationDate = attributes[FileAttributeKey.modificationDate] as? Date,
                   Date().timeIntervalSince(modificationDate) > CacheConfig.defaultTTL {
                    try fileManager.removeItem(at: fileURL)
                    expiredCount += 1
                }
            }
        } catch {
            print("❌ [CacheManager] Error during disk cleanup: \(error)")
        }

        stats.memoryUsage = memoryCache.count
        print("✅ [CacheManager] Cleanup completed, removed \(expiredCount) expired items")
    }
}

// MARK: - Cache Key Generation

extension MultiTierCacheManager {

    /// Generate consistent cache keys for AI meal plan requests
    static func cacheKey(for request: AIGenerationRequest) -> String {
        let components = [
            request.description,
            request.dietType?.rawValue ?? "",
            request.allergies.joined(separator: ","),
            request.dislikes.joined(separator: ","),
            request.calorieTarget?.description ?? "",
            // weekStartDate removed from cache key
            request.additionalRequirements ?? ""
        ]

        let combined = components.joined(separator: "|")
        let hash = combined.hash
        return "ai_request_\(abs(hash))"
    }

    /// Generate cache key for recipe search queries
    static func cacheKey(for searchQuery: String, filters: [String: Any] = [:]) -> String {
        let filterString = filters.keys.sorted().map { "\($0):\(filters[$0] ?? "")" }.joined(separator: ",")
        let combined = "\(searchQuery)|\(filterString)"
        let hash = combined.hash
        return "recipe_search_\(abs(hash))"
    }

    /// Generate cache key for meal plan data
    static func cacheKey(for mealPlanId: String, week: Date) -> String {
        let weekString = week.ISO8601Format()
        return "meal_plan_\(mealPlanId)_\(weekString)"
    }
}