//
//  LocalMealPlanStorage.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/27/25.
//  Updated to use user-scoped storage for data isolation
//

import Foundation

// MARK: - Local Storage Errors
enum LocalStorageError: LocalizedError {
    case encodingFailed(Error)
    case decodingFailed(Error)
    case saveVerificationFailed
    case userScopedStorageError(UserScopedStorageError)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed(let error):
            return "Failed to encode meal plan data: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode meal plan data: \(error.localizedDescription)"
        case .saveVerificationFailed:
            return "Data was not saved properly - verification failed"
        case .userScopedStorageError(let error):
            return "User scoped storage error: \(error.localizedDescription)"
        }
    }
}

class LocalMealPlanStorage {
    static let shared = LocalMealPlanStorage()
    private let userScopedStorage = UserScopedStorageManager.shared
    
    
    private init() {
        // Migration is now handled by UserScopedStorageManager
        // when a user logs in
    }
    
    // MARK: - Constants
    private let weeklyMealPlanKey = "weeklyMealPlan" // Legacy key
    private let multiWeekKeyPrefix = "weeklyMealPlan_"
    private let maxStoredWeeks = 6
    
    
    // MARK: - Storage Methods
    
    /// Save weekly meal plan using the grid's inherent date information
    func saveWeeklyMealPlan(_ weeklyGrid: WeeklyMealGrid) -> Result<Void, LocalStorageError> {
        let weekStartDate = weeklyGrid.getWeekStartDate()
        let normalizedDate = normalizeWeekStartDate(weekStartDate)
        let weekKey = generateWeekKey(for: normalizedDate)
        
        do {
            // Save to file system using user-scoped storage
            try userScopedStorage.setFileSystemValue(weeklyGrid, forKey: weekKey)
            
            // Backup to UserDefaults using user-scoped storage
            userScopedStorage.setUserDefaultsValue(weeklyGrid, forKey: weekKey)
            
            // Cleanup old weeks
            cleanupOldWeeks()
            
            print("✅ [LocalMealPlanStorage] Saved meal plan for week: \(formatWeekDate(normalizedDate))")
            return .success(())
        } catch let error as UserScopedStorageError {
            return .failure(.userScopedStorageError(error))
        } catch {
            return .failure(.encodingFailed(error))
        }
    }
    
    
    /// Load weekly meal plan for a specific week (method kept for compatibility)
    func loadWeeklyMealPlan(for weekStartDate: Date) -> WeeklyMealGrid? {
        let normalizedDate = normalizeWeekStartDate(weekStartDate)
        let weekKey = generateWeekKey(for: normalizedDate)
        
        // Try to load from file system using user-scoped storage
        if let weeklyGrid: WeeklyMealGrid = userScopedStorage.getFileSystemValue(forKey: weekKey, type: WeeklyMealGrid.self) {
            return weeklyGrid
        }
        
        // Fallback to UserDefaults using user-scoped storage
        if let weeklyGrid: WeeklyMealGrid = userScopedStorage.getUserDefaultsValue(forKey: weekKey, type: WeeklyMealGrid.self) {
            // Save to file system for future use
            _ = saveWeeklyMealPlan(weeklyGrid)
            return weeklyGrid
        }
        
        return nil
    }
    
    /// Clear meal plan for a specific week
    func clearMealPlan(for weekStartDate: Date) {
        let normalizedDate = normalizeWeekStartDate(weekStartDate)
        let weekKey = generateWeekKey(for: normalizedDate)
        
        // Clear from file system using user-scoped storage
        userScopedStorage.removeFileSystemValue(forKey: weekKey)
        
        // Clear from UserDefaults using user-scoped storage
        userScopedStorage.removeUserDefaultsValue(forKey: weekKey)
        
        print("🗑️ [LocalMealPlanStorage] Cleared meal plan for week: \(formatWeekDate(normalizedDate))")
    }
    
    /// Get all stored week start dates
    func getAllStoredWeeks() -> [Date] {
        var dates: [Date] = []
        
        // Get all user-scoped keys
        let userKeys = userScopedStorage.getCurrentUserKeys()
        
        // Process file system keys
        let fileSystemWeekKeys = userKeys.fileSystemKeys.filter { $0.hasPrefix(multiWeekKeyPrefix) }
        dates.append(contentsOf: fileSystemWeekKeys.compactMap { key -> Date? in
            let dateString = String(key.dropFirst(multiWeekKeyPrefix.count))
            return weekDateFormatter.date(from: dateString)
        })
        
        // Process UserDefaults keys
        let userDefaultsWeekKeys = userKeys.userDefaultsKeys.filter { $0.hasPrefix(multiWeekKeyPrefix) }
        dates.append(contentsOf: userDefaultsWeekKeys.compactMap { key -> Date? in
            let dateString = String(key.dropFirst(multiWeekKeyPrefix.count))
            return weekDateFormatter.date(from: dateString)
        })
        
        return Array(Set(dates)).sorted()
    }
    
    // MARK: - Cleanup Methods
    
    /// Clear all stored meal plans
    func clearAllMealPlans() {
        let storedWeeks = getAllStoredWeeks()
        
        for week in storedWeeks {
            clearMealPlan(for: week)
        }
        
        print("🗑️ [LocalMealPlanStorage] Cleared all stored meal plans")
    }
    
    /// Force cleanup of invalid weeks (outside ±4 weeks from current)
    func forceCleanupInvalidWeeks() {
        let calendar = Calendar.mondayFirst
        let currentWeekStart = Date().startOfWeek(using: calendar)
        
        let storedWeeks = getAllStoredWeeks()
        for week in storedWeeks {
            let weekDifference = calendar.dateComponents([.weekOfYear], from: currentWeekStart, to: week).weekOfYear ?? 0
            if abs(weekDifference) > 4 {
                clearMealPlan(for: week)
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func generateWeekKey(for weekStartDate: Date) -> String {
        "\(multiWeekKeyPrefix)\(formatWeekDate(weekStartDate))"
    }
    
    private func formatWeekDate(_ date: Date) -> String {
        weekDateFormatter.string(from: date)
    }
    
    /// Normalize week start date to remove time components and ensure consistency
    private func normalizeWeekStartDate(_ date: Date) -> Date {
        let calendar = Calendar.mondayFirst
        let weekStart = date.startOfWeek(using: calendar)
        let components = calendar.dateComponents([.year, .month, .day], from: weekStart)
        return calendar.date(from: components) ?? weekStart
    }
    
    private func cleanupOldWeeks() {
        let storedWeeks = getAllStoredWeeks()
        if storedWeeks.count > maxStoredWeeks {
            let weeksToRemove = storedWeeks.dropLast(maxStoredWeeks)
            weeksToRemove.forEach { clearMealPlan(for: $0) }
        }
    }
    
    
    // MARK: - Recipe Search Methods
    
    /// Find a recipe in local storage across all stored weeks
    /// This is used to lookup recipes when creating templates
    func findRecipeInLocalStorage(recipeId: String) -> Recipe? {
        print("🔍 [LocalMealPlanStorage] Searching for recipe \(recipeId) in local storage...")
        
        // Get all stored weeks
        let storedWeeks = getAllStoredWeeks()
        
        for weekDate in storedWeeks {
            if let weeklyGrid = loadWeeklyMealPlan(for: weekDate) {
                // Search through all meals in this week
                for dayMeals in weeklyGrid.dailyMeals {
                    // Check breakfast meals
                    for recipe in dayMeals.breakfast {
                        if recipe.id == recipeId {
                            print("✅ [LocalMealPlanStorage] Found recipe '\(recipe.name)' in breakfast meals")
                            return recipe
                        }
                    }
                    
                    // Check lunch meals  
                    for recipe in dayMeals.lunch {
                        if recipe.id == recipeId {
                            print("✅ [LocalMealPlanStorage] Found recipe '\(recipe.name)' in lunch meals")
                            return recipe
                        }
                    }
                    
                    // Check dinner meals
                    for recipe in dayMeals.dinner {
                        if recipe.id == recipeId {
                            print("✅ [LocalMealPlanStorage] Found recipe '\(recipe.name)' in dinner meals")
                            return recipe
                        }
                    }
                }
            }
        }
        
        print("❌ [LocalMealPlanStorage] Recipe \(recipeId) not found in any local storage")
        return nil
    }
    
    // MARK: - Date Formatter
    
    private lazy var weekDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}