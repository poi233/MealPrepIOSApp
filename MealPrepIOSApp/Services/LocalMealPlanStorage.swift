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
    
    /// Save weekly meal plan for a specific week
    func saveWeeklyMealPlan(for weekStartDate: Date, _ weeklyGrid: WeeklyMealGrid) -> Result<Void, LocalStorageError> {
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
    
    
    /// Load weekly meal plan for a specific week
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
            _ = saveWeeklyMealPlan(for: normalizedDate, weeklyGrid)
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
    
    /// Force cleanup of invalid weeks (outside ±4 weeks from current)
    func forceCleanupInvalidWeeks() {
        let calendar = Calendar.current
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        
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
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: components) ?? date
    }
    
    private func cleanupOldWeeks() {
        let storedWeeks = getAllStoredWeeks()
        if storedWeeks.count > maxStoredWeeks {
            let weeksToRemove = storedWeeks.dropLast(maxStoredWeeks)
            weeksToRemove.forEach { clearMealPlan(for: $0) }
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