//
//  LocalMealPlanStorage.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/22/25.
//

import Foundation

class LocalMealPlanStorage {
    static let shared = LocalMealPlanStorage()
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - Constants
    private let weeklyMealPlanKey = "weeklyMealPlan" // Legacy key for backward compatibility
    private let multiWeekKeyPrefix = "weeklyMealPlan_"
    private let maxStoredWeeks = 6 // Keep last 6 weeks to prevent unlimited storage growth
    
    // MARK: - Multi-Week Storage Methods
    
    /// Save weekly meal plan for a specific week
    func saveWeeklyMealPlan(for weekStartDate: Date, _ weeklyGrid: WeeklyMealGrid) {
        let key = generateWeekKey(for: weekStartDate)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(weeklyGrid)
            userDefaults.set(data, forKey: key)
            
            print("✅ Saved meal plan for week \(formatWeekDate(weekStartDate)) with key: \(key)")
            
            // Clean up old weeks to prevent storage growth
            cleanupOldWeeks()
            
        } catch {
            print("❌ Failed to save meal plan for week \(formatWeekDate(weekStartDate)): \(error)")
        }
    }
    
    /// Load weekly meal plan for a specific week
    func loadWeeklyMealPlan(for weekStartDate: Date) -> WeeklyMealGrid? {
        let key = generateWeekKey(for: weekStartDate)
        
        guard let data = userDefaults.data(forKey: key) else {
            print("📝 No stored meal plan found for week \(formatWeekDate(weekStartDate))")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let weeklyGrid = try decoder.decode(WeeklyMealGrid.self, from: data)
            print("✅ Loaded meal plan for week \(formatWeekDate(weekStartDate))")
            return weeklyGrid
        } catch {
            print("❌ Failed to load meal plan for week \(formatWeekDate(weekStartDate)): \(error)")
            return nil
        }
    }
    
    /// Clear meal plan for a specific week
    func clearMealPlan(for weekStartDate: Date) {
        let key = generateWeekKey(for: weekStartDate)
        userDefaults.removeObject(forKey: key)
        print("✅ Cleared meal plan for week \(formatWeekDate(weekStartDate))")
    }
    
    /// Get all stored week start dates
    func getAllStoredWeeks() -> [Date] {
        let allKeys = Array(userDefaults.dictionaryRepresentation().keys)
        let weekKeys = allKeys.filter { $0.hasPrefix(multiWeekKeyPrefix) }
        
        let dates = weekKeys.compactMap { key -> Date? in
            let dateString = String(key.dropFirst(multiWeekKeyPrefix.count))
            return weekDateFormatter.date(from: dateString)
        }
        
        return dates.sorted()
    }
    
    // MARK: - Legacy Methods (Deprecated but kept for backward compatibility)
    
    /// Save weekly meal plan to local storage (Legacy method - uses current week)
    @available(*, deprecated, message: "Use saveWeeklyMealPlan(for:_:) instead")
    func saveWeeklyMealPlan(_ weeklyGrid: WeeklyMealGrid) {
        saveWeeklyMealPlan(for: weeklyGrid.weekStartDate, weeklyGrid)
    }
    
    /// Load weekly meal plan from local storage (Legacy method - tries to load current week)
    @available(*, deprecated, message: "Use loadWeeklyMealPlan(for:) instead")
    func loadWeeklyMealPlan() -> WeeklyMealGrid? {
        // Try to migrate legacy data first
        migrateLegacyDataIfNeeded()
        
        // Return the most recent stored week
        let storedWeeks = getAllStoredWeeks()
        guard let mostRecentWeek = storedWeeks.last else {
            return nil
        }
        
        return loadWeeklyMealPlan(for: mostRecentWeek)
    }
    
    /// Clear local meal plan (Legacy method)
    @available(*, deprecated, message: "Use clearMealPlan(for:) instead")
    func clearLocalMealPlan() {
        // Clear legacy storage
        userDefaults.removeObject(forKey: weeklyMealPlanKey)
        
        // Clear all multi-week storage
        let storedWeeks = getAllStoredWeeks()
        for week in storedWeeks {
            clearMealPlan(for: week)
        }
        
        print("✅ Cleared all local meal plans")
    }
    
    // MARK: - Private Helper Methods
    
    private func generateWeekKey(for weekStartDate: Date) -> String {
        let dateString = weekDateFormatter.string(from: weekStartDate)
        return "\(multiWeekKeyPrefix)\(dateString)"
    }
    
    private func formatWeekDate(_ date: Date) -> String {
        return weekDateFormatter.string(from: date)
    }
    
    private func cleanupOldWeeks() {
        let storedWeeks = getAllStoredWeeks()
        
        if storedWeeks.count > maxStoredWeeks {
            let weeksToRemove = storedWeeks.dropLast(maxStoredWeeks)
            
            for weekToRemove in weeksToRemove {
                clearMealPlan(for: weekToRemove)
                print("🧹 Cleaned up old meal plan for week \(formatWeekDate(weekToRemove))")
            }
            
            if !weeksToRemove.isEmpty {
                print("🧹 Cleanup completed: removed \(weeksToRemove.count) old week(s)")
            }
        }
    }
    
    private func migrateLegacyDataIfNeeded() {
        // Check if legacy data exists and hasn't been migrated
        guard let legacyData = userDefaults.data(forKey: weeklyMealPlanKey) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let legacyGrid = try decoder.decode(WeeklyMealGrid.self, from: legacyData)
            
            // Save to new multi-week system
            saveWeeklyMealPlan(for: legacyGrid.weekStartDate, legacyGrid)
            
            // Remove legacy data
            userDefaults.removeObject(forKey: weeklyMealPlanKey)
            
            print("🔄 Migrated legacy meal plan data to multi-week storage")
            
        } catch {
            print("❌ Failed to migrate legacy meal plan data: \(error)")
        }
    }
    
    // MARK: - Date Formatter
    
    private lazy var weekDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}