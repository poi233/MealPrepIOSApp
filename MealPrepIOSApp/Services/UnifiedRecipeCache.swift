//
//  UnifiedRecipeCache.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/26/25.
//  集中缓存管理，优化Recipe选择功能的API调用策略
//

import Foundation

/// 统一的Recipe缓存管理类
/// 用于MealPlan添加Recipe功能，实现智能缓存和分页策略
class UnifiedRecipeCache: ObservableObject {
    
    // MARK: - Initialization
    
    init() {
        setupNotificationObservers()
    }
    // MARK: - Cache Properties
    private var cachedRecipes: [Recipe] = []
    private var nextPageToken: String?
    private var lastRefreshTime: Date?
    private var currentSearchQuery: String = ""
    private let cacheValidDuration: TimeInterval = 300 // 5分钟缓存有效期
    private let pageSize = 5 // 每页5个recipe
    
    // MARK: - Cache State
    var recipes: [Recipe] {
        return cachedRecipes
    }
    
    var hasMorePages: Bool {
        return nextPageToken != nil && !nextPageToken!.isEmpty
    }
    
    var isCacheValid: Bool {
        guard let lastRefresh = lastRefreshTime else { return false }
        return Date().timeIntervalSince(lastRefresh) < cacheValidDuration
    }
    
    var cacheAge: TimeInterval {
        guard let lastRefresh = lastRefreshTime else { return TimeInterval.infinity }
        return Date().timeIntervalSince(lastRefresh)
    }
    
    // MARK: - Public Methods
    
    /// 检查是否需要重新加载数据
    /// - Parameters:
    ///   - searchQuery: 当前搜索查询
    ///   - forceRefresh: 是否强制刷新
    /// - Returns: 是否需要调用API
    func shouldLoadData(searchQuery: String = "", forceRefresh: Bool = false) -> Bool {
        // 强制刷新
        if forceRefresh {
            print("🔄 [UnifiedRecipeCache] Force refresh requested")
            return true
        }
        
        // 搜索查询改变
        if searchQuery != currentSearchQuery {
            print("🔍 [UnifiedRecipeCache] Search query changed: '\(currentSearchQuery)' -> '\(searchQuery)'")
            return true
        }
        
        // 首次加载（无缓存数据）
        if cachedRecipes.isEmpty {
            print("📥 [UnifiedRecipeCache] No cached data, need to load")
            return true
        }
        
        // 缓存过期
        if !isCacheValid {
            print("⏰ [UnifiedRecipeCache] Cache expired (age: \(Int(cacheAge))s)")
            return true
        }
        
        print("✅ [UnifiedRecipeCache] Using cached data (age: \(Int(cacheAge))s, count: \(cachedRecipes.count))")
        return false
    }
    
    /// 更新缓存数据（首次加载或刷新）
    /// - Parameters:
    ///   - recipes: 新的recipe数据
    ///   - nextToken: 下一页的token
    ///   - searchQuery: 搜索查询
    ///   - isRefresh: 是否为刷新操作
    func updateCache(recipes: [Recipe], nextToken: String?, searchQuery: String = "", isRefresh: Bool = false) {
        if isRefresh {
            // 刷新时重置所有数据
            self.cachedRecipes = recipes
            print("🔄 [UnifiedRecipeCache] Cache refreshed with \(recipes.count) recipes")
        } else {
            // 追加数据（分页加载）
            self.cachedRecipes.append(contentsOf: recipes)
            print("📝 [UnifiedRecipeCache] Appended \(recipes.count) recipes, total: \(self.cachedRecipes.count)")
        }
        
        self.nextPageToken = nextToken
        self.currentSearchQuery = searchQuery
        self.lastRefreshTime = Date()
        
        print("🏷️ [UnifiedRecipeCache] Updated - NextToken: \(nextToken ?? "nil"), SearchQuery: '\(searchQuery)'")
    }
    
    /// 获取下一页token用于分页加载
    /// - Returns: 下一页token，如果没有更多页面则返回nil
    func getNextPageToken() -> String? {
        return nextPageToken
    }
    
    // MARK: - Setup Methods
    
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
            self?.clearCache()
        }
    }
    
    /// Remove a deleted recipe from cache
    private func removeDeletedRecipe(recipeId: String) {
        let originalCount = cachedRecipes.count
        cachedRecipes.removeAll { $0.id == recipeId }
        
        let removedCount = originalCount - cachedRecipes.count
        if removedCount > 0 {
            print("🧹 [UnifiedRecipeCache] Removed \(removedCount) deleted recipe(s) from cache")
        }
    }
    
    /// 清空缓存
    func clearCache() {
        cachedRecipes.removeAll()
        nextPageToken = nil
        lastRefreshTime = nil
        currentSearchQuery = ""
        print("🗑️ [UnifiedRecipeCache] Cache cleared")
    }
    
    /// Cleanup method for deinit
    deinit {
        // Remove observers to prevent memory leaks
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 获取缓存统计信息
    func getCacheStats() -> String {
        let ageText = lastRefreshTime != nil ? "\(Int(cacheAge))s ago" : "never"
        return "Recipes: \(cachedRecipes.count), LastRefresh: \(ageText), Valid: \(isCacheValid)"
    }
}

// MARK: - Extension for Recipe Selection
extension UnifiedRecipeCache {
    /// 专门用于MealSelection的数据检查
    /// 确保数据符合MealPlan添加Recipe的需求
    func validateRecipesForMealSelection() -> Bool {
        // 检查recipe数据完整性
        let validRecipes = cachedRecipes.filter { recipe in
            !recipe.id.isEmpty && !recipe.name.isEmpty
        }
        
        if validRecipes.count != cachedRecipes.count {
            print("⚠️ [UnifiedRecipeCache] Found \(cachedRecipes.count - validRecipes.count) invalid recipes")
            cachedRecipes = validRecipes
        }
        
        return !cachedRecipes.isEmpty
    }
    
    /// 获取适合显示的recipe子集
    /// 用于控制首屏显示的recipe数量
    func getDisplayRecipes(limit: Int? = nil) -> [Recipe] {
        guard let limit = limit else { return cachedRecipes }
        return Array(cachedRecipes.prefix(limit))
    }
}