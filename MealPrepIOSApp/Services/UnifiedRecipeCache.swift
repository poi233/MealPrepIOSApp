//
//  UnifiedRecipeCache.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/26/25.
//  集中缓存管理，优化Recipe选择功能的API调用策略
//  Updated: 7/27/25 - Task 3: Cache System Fixes and Crash Prevention
//

import Foundation
import Combine
import UIKit

// MARK: - Cache Errors
enum CacheError: LocalizedError {
    case storageFailure(Error)
    case invalidData(String)
    case userContextMissing
    case corruptedCache(String)
    case persistenceFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .storageFailure(let error):
            return "Cache storage failure: \(error.localizedDescription)"
        case .invalidData(let details):
            return "Invalid cache data: \(details)"
        case .userContextMissing:
            return "User context is required for cache operations"
        case .corruptedCache(let details):
            return "Cache data is corrupted: \(details)"
        case .persistenceFailed(let error):
            return "Failed to persist cache: \(error.localizedDescription)"
        }
    }
}

// MARK: - Cache Configuration
struct CacheConfiguration {
    let maxMemoryItems: Int
    let persistentStorageEnabled: Bool
    let cacheValidDuration: TimeInterval
    let pageSize: Int
    let maxRetryAttempts: Int
    
    static let `default` = CacheConfiguration(
        maxMemoryItems: 100,
        persistentStorageEnabled: true,
        cacheValidDuration: 300, // 5 minutes
        pageSize: 5,
        maxRetryAttempts: 3
    )
}

// MARK: - Cache Entry
private struct CacheEntry: Codable {
    let recipes: [Recipe]
    let nextPageToken: String?
    let searchQuery: String
    let timestamp: Date
    let version: Int
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 300 // 5 minutes
    }
    
    init(recipes: [Recipe], nextPageToken: String?, searchQuery: String) {
        self.recipes = recipes
        self.nextPageToken = nextPageToken
        self.searchQuery = searchQuery
        self.timestamp = Date()
        self.version = 1 // For future cache format migrations
    }
}

// MARK: - Cache Statistics
struct CacheStatistics {
    let memoryItemCount: Int
    let persistentItemCount: Int
    let lastRefreshTime: Date?
    let isValid: Bool
    let cacheAge: TimeInterval
    let errorCount: Int
    let hitRate: Double
}

/// 统一的Recipe缓存管理类
/// 用于MealPlan添加Recipe功能，实现智能缓存和分页策略
/// Enhanced with crash prevention, user-scoped storage, and comprehensive error handling
class UnifiedRecipeCache: ObservableObject {
    
    // MARK: - Dependencies
    private let storageManager: UserScopedStorageManager
    private let configuration: CacheConfiguration
    
    // MARK: - Cache State
    private var memoryCache: [String: CacheEntry] = [:]
    private let cacheQueue = DispatchQueue(label: "com.mealprep.cache", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Current Cache State
    @Published private var currentCacheEntry: CacheEntry?
    private var lastAccessTime: Date?
    
    // MARK: - Statistics
    private var accessCount: Int = 0
    private var hitCount: Int = 0
    private var errorCount: Int = 0
    
    // MARK: - Constants
    private let cacheKeyPrefix = "recipe_cache"
    private let statsKey = "cache_statistics"
    
    // MARK: - Initialization
    
    init(storageManager: UserScopedStorageManager = .shared, 
         configuration: CacheConfiguration = .default) {
        self.storageManager = storageManager
        self.configuration = configuration
        setupNotificationObservers()
        loadCacheFromPersistentStorage()
    }
    
    // MARK: - Public Properties
    
    var recipes: [Recipe] {
        return currentCacheEntry?.recipes ?? []
    }
    
    var hasMorePages: Bool {
        return currentCacheEntry?.nextPageToken != nil && !currentCacheEntry!.nextPageToken!.isEmpty
    }
    
    var isCacheValid: Bool {
        guard let entry = currentCacheEntry else { return false }
        return !entry.isExpired
    }
    
    var cacheAge: TimeInterval {
        guard let entry = currentCacheEntry else { return TimeInterval.infinity }
        return Date().timeIntervalSince(entry.timestamp)
    }
    
    // MARK: - Public Methods
    
    /// 检查是否需要重新加载数据 - Enhanced with error handling
    /// - Parameters:
    ///   - searchQuery: 当前搜索查询
    ///   - forceRefresh: 是否强制刷新
    /// - Returns: 是否需要调用API
    func shouldLoadData(searchQuery: String = "", forceRefresh: Bool = false) -> Bool {
        accessCount += 1
        lastAccessTime = Date()
        
        do {
            return try performShouldLoadDataCheck(searchQuery: searchQuery, forceRefresh: forceRefresh)
        } catch {
            handleError(error, context: "shouldLoadData")
            return true // Default to loading data on error
        }
    }
    
    private func performShouldLoadDataCheck(searchQuery: String, forceRefresh: Bool) throws -> Bool {
        // 强制刷新
        if forceRefresh {
            print("🔄 [UnifiedRecipeCache] Force refresh requested")
            try clearMemoryCache()
            return true
        }
        
        // 搜索查询改变
        if searchQuery != (currentCacheEntry?.searchQuery ?? "") {
            print("🔍 [UnifiedRecipeCache] Search query changed: '\(currentCacheEntry?.searchQuery ?? "")' -> '\(searchQuery)'")
            try loadCacheEntryForQuery(searchQuery)
            
            // Check if we have valid cached data for the new query
            if let entry = currentCacheEntry, !entry.isExpired {
                hitCount += 1
                return false
            }
            return true
        }
        
        // 首次加载（无缓存数据）
        if currentCacheEntry == nil || recipes.isEmpty {
            print("📥 [UnifiedRecipeCache] No cached data, need to load")
            return true
        }
        
        // 缓存过期
        if !isCacheValid {
            print("⏰ [UnifiedRecipeCache] Cache expired (age: \(Int(cacheAge))s)")
            return true
        }
        
        print("✅ [UnifiedRecipeCache] Using cached data (age: \(Int(cacheAge))s, count: \(recipes.count))")
        hitCount += 1
        return false
    }
    
    /// 更新缓存数据（首次加载或刷新）- Enhanced with persistence and validation
    /// - Parameters:
    ///   - recipes: 新的recipe数据
    ///   - nextToken: 下一页的token
    ///   - searchQuery: 搜索查询
    ///   - isRefresh: 是否为刷新操作
    func updateCache(recipes: [Recipe], nextToken: String?, searchQuery: String = "", isRefresh: Bool = false) {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.performCacheUpdate(recipes: recipes, nextToken: nextToken, searchQuery: searchQuery, isRefresh: isRefresh)
            } catch {
                self.handleError(error, context: "updateCache")
            }
        }
    }
    
    private func performCacheUpdate(recipes: [Recipe], nextToken: String?, searchQuery: String, isRefresh: Bool) throws {
        // Validate input data
        try validateRecipeData(recipes)
        
        let validatedRecipes = recipes.filter { !$0.id.isEmpty && !$0.name.isEmpty }
        if validatedRecipes.count != recipes.count {
            print("⚠️ [UnifiedRecipeCache] Filtered out \(recipes.count - validatedRecipes.count) invalid recipes")
        }
        
        var updatedRecipes: [Recipe]
        
        if isRefresh {
            // 刷新时重置所有数据
            updatedRecipes = validatedRecipes
            print("🔄 [UnifiedRecipeCache] Cache refreshed with \(validatedRecipes.count) recipes")
        } else {
            // 追加数据（分页加载）
            let existingRecipes = currentCacheEntry?.recipes ?? []
            updatedRecipes = existingRecipes + validatedRecipes
            
            // Remove duplicates based on recipe ID
            var seenIDs = Set<String>()
            updatedRecipes = updatedRecipes.filter { recipe in
                if seenIDs.contains(recipe.id) {
                    return false
                }
                seenIDs.insert(recipe.id)
                return true
            }
            
            print("📝 [UnifiedRecipeCache] Appended \(validatedRecipes.count) recipes, total: \(updatedRecipes.count)")
        }
        
        // Create new cache entry
        let newEntry = CacheEntry(recipes: updatedRecipes, nextPageToken: nextToken, searchQuery: searchQuery)
        
        // Update memory cache
        DispatchQueue.main.async {
            self.currentCacheEntry = newEntry
        }
        
        // Update persistent cache
        try persistCacheEntry(newEntry, for: searchQuery)
        
        // Update in-memory cache
        let cacheKey = generateCacheKey(for: searchQuery)
        memoryCache[cacheKey] = newEntry
        
        // Enforce memory limits
        enforceMemoryLimits()
        
        print("🏷️ [UnifiedRecipeCache] Updated - NextToken: \(nextToken ?? "nil"), SearchQuery: '\(searchQuery)'")
    }
    
    /// 获取下一页token用于分页加载
    /// - Returns: 下一页token，如果没有更多页面则返回nil
    func getNextPageToken() -> String? {
        return currentCacheEntry?.nextPageToken
    }
    
    /// 清空缓存 - Enhanced with comprehensive cleanup
    func clearCache() {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.performCacheClear()
            } catch {
                self.handleError(error, context: "clearCache")
            }
        }
    }
    
    private func performCacheClear() throws {
        // Clear memory cache
        try clearMemoryCache()
        
        // Clear persistent cache
        try clearPersistentCache()
        
        // Reset statistics
        resetStatistics()
        
        print("🗑️ [UnifiedRecipeCache] Cache cleared completely")
    }
    
    // MARK: - Cache Validation
    
    /// 专门用于MealSelection的数据检查 - Enhanced with comprehensive validation
    /// 确保数据符合MealPlan添加Recipe的需求
    func validateRecipesForMealSelection() -> Bool {
        do {
            return try performMealSelectionValidation()
        } catch {
            handleError(error, context: "validateRecipesForMealSelection")
            return false
        }
    }
    
    private func performMealSelectionValidation() throws -> Bool {
        guard let entry = currentCacheEntry else {
            print("ℹ️ [UnifiedRecipeCache] No cache entry for validation")
            return false
        }
        
        // Check cache expiry
        if entry.isExpired {
            print("⚠️ [UnifiedRecipeCache] Cache entry expired during validation")
            return false
        }
        
        // Validate recipe data integrity
        let validRecipes = entry.recipes.filter { recipe in
            !recipe.id.isEmpty && 
            !recipe.name.isEmpty &&
            recipe.id.count > 0 &&
            recipe.name.count > 0
        }
        
        if validRecipes.count != entry.recipes.count {
            print("⚠️ [UnifiedRecipeCache] Found \(entry.recipes.count - validRecipes.count) invalid recipes during validation")
            
            // Update cache with valid recipes only
            let updatedEntry = CacheEntry(
                recipes: validRecipes,
                nextPageToken: entry.nextPageToken,
                searchQuery: entry.searchQuery
            )
            
            DispatchQueue.main.async {
                self.currentCacheEntry = updatedEntry
            }
        }
        
        let isValid = !validRecipes.isEmpty
        print("✅ [UnifiedRecipeCache] Validation result: \(isValid) (valid recipes: \(validRecipes.count))")
        return isValid
    }
    
    /// 获取适合显示的recipe子集 - Enhanced with error handling
    /// 用于控制首屏显示的recipe数量
    func getDisplayRecipes(limit: Int? = nil) -> [Recipe] {
        do {
            return try performGetDisplayRecipes(limit: limit)
        } catch {
            handleError(error, context: "getDisplayRecipes")
            return []
        }
    }
    
    private func performGetDisplayRecipes(limit: Int?) throws -> [Recipe] {
        guard let entry = currentCacheEntry else {
            return []
        }
        
        if entry.isExpired {
            print("⚠️ [UnifiedRecipeCache] Cache expired while getting display recipes")
            return []
        }
        
        let recipes = entry.recipes
        guard let limit = limit else { return recipes }
        
        let limitedRecipes = Array(recipes.prefix(max(0, limit)))
        print("📱 [UnifiedRecipeCache] Returning \(limitedRecipes.count) display recipes (limit: \(limit))")
        
        return limitedRecipes
    }
    
    // MARK: - Statistics and Monitoring
    
    /// 获取缓存统计信息 - Enhanced with comprehensive metrics
    func getCacheStats() -> CacheStatistics {
        let hitRate = accessCount > 0 ? Double(hitCount) / Double(accessCount) : 0.0
        
        return CacheStatistics(
            memoryItemCount: memoryCache.count,
            persistentItemCount: getPersistentCacheCount(),
            lastRefreshTime: currentCacheEntry?.timestamp,
            isValid: isCacheValid,
            cacheAge: cacheAge,
            errorCount: errorCount,
            hitRate: hitRate
        )
    }
    
    func getCacheStatsString() -> String {
        let stats = getCacheStats()
        let ageText = stats.lastRefreshTime != nil ? "\(Int(stats.cacheAge))s ago" : "never"
        return "Recipes: \(recipes.count), LastRefresh: \(ageText), Valid: \(stats.isValid), HitRate: \(String(format: "%.1f%%", stats.hitRate * 100))"
    }
    
    // MARK: - Private Helper Methods
    
    private func setupNotificationObservers() {
        // Listen for recipe deletion notifications
        NotificationCenter.default.addObserver(
            forName: .recipeDeleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let recipeId = notification.userInfo?[RecipeDeletionNotificationKeys.recipeId] as? String {
                self?.removeDeletedRecipe(recipeId: recipeId)
            }
        }
        
        // Listen for user logout to clear cache
        NotificationCenter.default.addObserver(
            forName: .userLoggedOut,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleUserLogout()
        }
        
        // Listen for user login to load cache
        NotificationCenter.default.addObserver(
            forName: .userLoggedIn,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleUserLogin()
        }
        
        // Memory warning handling
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func validateRecipeData(_ recipes: [Recipe]) throws {
        for (index, recipe) in recipes.enumerated() {
            if recipe.id.isEmpty {
                throw CacheError.invalidData("Recipe at index \(index) has empty ID")
            }
            if recipe.name.isEmpty {
                throw CacheError.invalidData("Recipe at index \(index) has empty name")
            }
        }
    }
    
    private func generateCacheKey(for searchQuery: String) -> String {
        let sanitizedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitizedQuery.isEmpty ? "default" : sanitizedQuery
    }
    
    private func loadCacheEntryForQuery(_ searchQuery: String) throws {
        let cacheKey = generateCacheKey(for: searchQuery)
        
        // First try memory cache
        if let memoryEntry = memoryCache[cacheKey] {
            currentCacheEntry = memoryEntry
            print("💾 [UnifiedRecipeCache] Loaded from memory cache: \(cacheKey)")
            return
        }
        
        // Then try persistent cache
        if configuration.persistentStorageEnabled {
            if let persistentEntry = try loadPersistentCacheEntry(for: searchQuery) {
                currentCacheEntry = persistentEntry
                memoryCache[cacheKey] = persistentEntry
                print("💽 [UnifiedRecipeCache] Loaded from persistent cache: \(cacheKey)")
                return
            }
        }
        
        // No cache found
        currentCacheEntry = nil
        print("🔍 [UnifiedRecipeCache] No cache found for query: \(cacheKey)")
    }
    
    private func loadCacheFromPersistentStorage() {
        guard configuration.persistentStorageEnabled else { return }
        
        cacheQueue.async { [weak self] in
            do {
                try self?.performInitialCacheLoad()
            } catch {
                self?.handleError(error, context: "loadCacheFromPersistentStorage")
            }
        }
    }
    
    private func performInitialCacheLoad() throws {
        // Try to load the default cache entry
        if let entry = try loadPersistentCacheEntry(for: "") {
            DispatchQueue.main.async {
                self.currentCacheEntry = entry
            }
            let cacheKey = generateCacheKey(for: entry.searchQuery)
            memoryCache[cacheKey] = entry
            print("🏁 [UnifiedRecipeCache] Loaded initial cache from persistent storage")
        }
    }
    
    private func persistCacheEntry(_ entry: CacheEntry, for searchQuery: String) throws {
        guard configuration.persistentStorageEnabled else { return }
        
        let cacheKey = "\(cacheKeyPrefix)_\(generateCacheKey(for: searchQuery))"
        
        do {
            try storageManager.setFileSystemValue(entry, forKey: cacheKey)
            print("💽 [UnifiedRecipeCache] Persisted cache entry: \(cacheKey)")
        } catch {
            throw CacheError.persistenceFailed(error)
        }
    }
    
    private func loadPersistentCacheEntry(for searchQuery: String) throws -> CacheEntry? {
        let cacheKey = "\(cacheKeyPrefix)_\(generateCacheKey(for: searchQuery))"
        
        let entry = storageManager.getFileSystemValue(forKey: cacheKey, type: CacheEntry.self)
        
        if let entry = entry {
            // Validate the loaded entry
            if entry.version != 1 {
                print("⚠️ [UnifiedRecipeCache] Cache entry has unsupported version: \(entry.version)")
                return nil
            }
            
            // Check if entry is too old
            if entry.isExpired {
                print("⏰ [UnifiedRecipeCache] Loaded cache entry is expired, discarding")
                try removePersistentCacheEntry(for: searchQuery)
                return nil
            }
        }
        
        return entry
    }
    
    private func removePersistentCacheEntry(for searchQuery: String) throws {
        let cacheKey = "\(cacheKeyPrefix)_\(generateCacheKey(for: searchQuery))"
        storageManager.removeFileSystemValue(forKey: cacheKey)
    }
    
    private func clearMemoryCache() throws {
        memoryCache.removeAll()
        currentCacheEntry = nil
        print("🧹 [UnifiedRecipeCache] Memory cache cleared")
    }
    
    private func clearPersistentCache() throws {
        guard configuration.persistentStorageEnabled else { return }
        
        let keys = storageManager.getCurrentUserKeys().fileSystemKeys
        let cacheKeys = keys.filter { $0.hasPrefix(cacheKeyPrefix) }
        
        for key in cacheKeys {
            storageManager.removeFileSystemValue(forKey: key)
        }
        
        print("🧹 [UnifiedRecipeCache] Persistent cache cleared (\(cacheKeys.count) entries)")
    }
    
    private func enforceMemoryLimits() {
        if memoryCache.count > configuration.maxMemoryItems {
            // Remove oldest entries based on timestamp
            let sortedEntries = memoryCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let entriesToRemove = sortedEntries.prefix(memoryCache.count - configuration.maxMemoryItems)
            
            for (key, _) in entriesToRemove {
                memoryCache.removeValue(forKey: key)
            }
            
            print("📦 [UnifiedRecipeCache] Enforced memory limit, removed \(entriesToRemove.count) entries")
        }
    }
    
    private func getPersistentCacheCount() -> Int {
        let keys = storageManager.getCurrentUserKeys().fileSystemKeys
        return keys.filter { $0.hasPrefix(cacheKeyPrefix) }.count
    }
    
    private func removeDeletedRecipe(recipeId: String) {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.performRecipeRemoval(recipeId: recipeId)
            } catch {
                self.handleError(error, context: "removeDeletedRecipe")
            }
        }
    }
    
    private func performRecipeRemoval(recipeId: String) throws {
        var wasUpdated = false
        
        // Update current cache entry
        if let entry = currentCacheEntry {
            let originalCount = entry.recipes.count
            let filteredRecipes = entry.recipes.filter { $0.id != recipeId }
            
            if filteredRecipes.count < originalCount {
                let updatedEntry = CacheEntry(
                    recipes: filteredRecipes,
                    nextPageToken: entry.nextPageToken,
                    searchQuery: entry.searchQuery
                )
                
                DispatchQueue.main.async {
                    self.currentCacheEntry = updatedEntry
                }
                
                try persistCacheEntry(updatedEntry, for: entry.searchQuery)
                wasUpdated = true
            }
        }
        
        // Update memory cache
        for (key, entry) in memoryCache {
            let originalCount = entry.recipes.count
            let filteredRecipes = entry.recipes.filter { $0.id != recipeId }
            
            if filteredRecipes.count < originalCount {
                let updatedEntry = CacheEntry(
                    recipes: filteredRecipes,
                    nextPageToken: entry.nextPageToken,
                    searchQuery: entry.searchQuery
                )
                
                memoryCache[key] = updatedEntry
                wasUpdated = true
            }
        }
        
        if wasUpdated {
            print("🧹 [UnifiedRecipeCache] Removed deleted recipe \(recipeId) from cache")
        }
    }
    
    private func handleUserLogout() {
        cacheQueue.async { [weak self] in
            do {
                try self?.performCacheClear()
                print("👋 [UnifiedRecipeCache] Cache cleared on user logout")
            } catch {
                self?.handleError(error, context: "handleUserLogout")
            }
        }
    }
    
    private func handleUserLogin() {
        cacheQueue.async { [weak self] in
            do {
                try self?.performInitialCacheLoad()
                print("👤 [UnifiedRecipeCache] Cache loaded on user login")
            } catch {
                self?.handleError(error, context: "handleUserLogin")
            }
        }
    }
    
    private func handleMemoryWarning() {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Clear memory cache but keep current entry
            let currentEntry = self.currentCacheEntry
            self.memoryCache.removeAll()
            
            if let entry = currentEntry {
                let cacheKey = self.generateCacheKey(for: entry.searchQuery)
                self.memoryCache[cacheKey] = entry
            }
            
            print("⚠️ [UnifiedRecipeCache] Memory cache cleared due to memory warning")
        }
    }
    
    private func handleError(_ error: Error, context: String) {
        errorCount += 1
        
        let errorMessage = "[UnifiedRecipeCache] Error in \(context): \(error.localizedDescription)"
        print("❌ \(errorMessage)")
        
        // Log error for debugging
        if let cacheError = error as? CacheError {
            print("💥 [UnifiedRecipeCache] Cache Error Details: \(cacheError)")
        }
        
        // Don't crash the app - this is a key requirement for crash prevention
        // Instead, ensure the cache remains in a valid state
        ensureCacheConsistency()
    }
    
    private func ensureCacheConsistency() {
        // Perform basic consistency checks and repairs
        if let entry = currentCacheEntry {
            // Check if entry has expired and clear if so
            if entry.isExpired {
                currentCacheEntry = nil
                print("🔧 [UnifiedRecipeCache] Cleared expired cache entry during consistency check")
            }
            
            // Validate recipe data
            let validRecipes = entry.recipes.filter { !$0.id.isEmpty && !$0.name.isEmpty }
            if validRecipes.count != entry.recipes.count {
                let repairedEntry = CacheEntry(
                    recipes: validRecipes,
                    nextPageToken: entry.nextPageToken,
                    searchQuery: entry.searchQuery
                )
                currentCacheEntry = repairedEntry
                print("🔧 [UnifiedRecipeCache] Repaired cache entry with \(validRecipes.count) valid recipes")
            }
        }
    }
    
    private func resetStatistics() {
        accessCount = 0
        hitCount = 0
        errorCount = 0
        lastAccessTime = nil
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Cancel any ongoing operations
        cancellables.removeAll()
        
        // Remove observers to prevent memory leaks
        NotificationCenter.default.removeObserver(self)
        
        print("🏁 [UnifiedRecipeCache] Cache manager deallocated")
    }
}

