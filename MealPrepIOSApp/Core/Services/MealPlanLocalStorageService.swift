//
//  MealPlanLocalStorageService.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 8/3/25.
//  Extracted from MealPlanStore.swift for better separation of concerns.
//

import Foundation

// MARK: - Local Storage Service
@MainActor
class MealPlanLocalStorageService: ObservableObject {

    // MARK: - Local Storage Operations

    func loadMealPlan(for weekStartDate: Date) -> WeeklyMealGrid? {
        return LocalMealPlanStorage.shared.loadWeeklyMealPlan(for: weekStartDate)
    }

    func saveMealPlan(_ weeklyGrid: WeeklyMealGrid) -> Result<Void, LocalStorageError> {
        return LocalMealPlanStorage.shared.saveWeeklyMealPlan(weeklyGrid)
    }

    func clearMealPlan(for weekStartDate: Date) {
        LocalMealPlanStorage.shared.clearMealPlan(for: weekStartDate)
    }

    // MARK: - Cleanup Operations

    /// Clean up stored weeks that are outside the allowed range
    func cleanupInvalidStoredWeeks() {
        let calendar = Calendar.mondayFirst
        let currentWeekStart = Date().startOfWeek()

        let storage = LocalMealPlanStorage.shared
        let storedWeeks = storage.getAllStoredWeeks()

        for week in storedWeeks {
            let weekDifference = calendar.dateComponents([.weekOfYear], from: currentWeekStart, to: week).weekOfYear ?? 0
            if abs(weekDifference) > 4 {
                storage.clearMealPlan(for: week)
            }
        }
    }

    func clearAllData() {
        LocalMealPlanStorage.shared.clearAllMealPlans()
    }

    // MARK: - Utility Methods

    func getAllStoredWeeks() -> [Date] {
        return LocalMealPlanStorage.shared.getAllStoredWeeks()
    }

    func hasStoredMealPlan(for weekStartDate: Date) -> Bool {
        return loadMealPlan(for: weekStartDate) != nil
    }

    func hasStoredMealPlan(for weeklyGrid: WeeklyMealGrid) -> Bool {
        let weekStartDate = weeklyGrid.getWeekStartDate()
        return loadMealPlan(for: weekStartDate) != nil
    }

    // MARK: - Date Normalization

    /// Normalize week start date to remove time components and ensure consistency
    func normalizeWeekStartDate(_ date: Date) -> Date {
        let calendar = Calendar.mondayFirst
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: components) ?? date
    }

    func formatWeekDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}