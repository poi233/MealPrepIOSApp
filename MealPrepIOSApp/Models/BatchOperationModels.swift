//
//  BatchOperationModels.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 8/9/25.
//  Models for batch operations functionality.
//

import Foundation
import SwiftUI

// MARK: - Batch Operation Result

struct BatchOperationResult {
    let isSuccess: Bool
    let title: String
    let message: String
    let itemCount: Int?
    let details: [String]?

    init(isSuccess: Bool, title: String, message: String, itemCount: Int? = nil, details: [String]? = nil) {
        self.isSuccess = isSuccess
        self.title = title
        self.message = message
        self.itemCount = itemCount
        self.details = details
    }
}

// MARK: - Batch Operation Types

enum BatchOperation: CaseIterable, Identifiable {
    case copyFromLastWeek
    case duplicateToNextWeek
    case clearAllMeals

    var id: String {
        switch self {
        case .copyFromLastWeek: return "copy-last-week"
        case .clearAllMeals: return "clear-all"
        case .duplicateToNextWeek: return "duplicate-next"
        }
    }

    var title: String {
        switch self {
        case .copyFromLastWeek: return "Copy from Last Week"
        case .clearAllMeals: return "Clear All Meals"
        case .duplicateToNextWeek: return "Duplicate to Next Week"
        }
    }

    var description: String {
        switch self {
        case .copyFromLastWeek: return "Copy all meals from the previous week"
        case .clearAllMeals: return "Remove all meals from this week"
        case .duplicateToNextWeek: return "Copy this week's meals to next week"
        }
    }

    var iconName: String {
        switch self {
        case .copyFromLastWeek: return "arrow.uturn.backward"
        case .clearAllMeals: return "trash"
        case .duplicateToNextWeek: return "arrow.uturn.forward"
        }
    }

    var color: Color {
        switch self {
        case .copyFromLastWeek: return .blue
        case .clearAllMeals: return .red
        case .duplicateToNextWeek: return .orange
        }
    }

    var requiresConfirmation: Bool {
        switch self {
        case .clearAllMeals: return true
        case .copyFromLastWeek: return true
        case .duplicateToNextWeek: return true
        default: return false
        }
    }

    var confirmationTitle: String {
        switch self {
        case .clearAllMeals: return "Clear All Meals?"
        case .copyFromLastWeek: return "Copy from Last Week?"
        case .duplicateToNextWeek: return "Duplicate to Next Week?"
        default: return "Confirm Action?"
        }
    }

    var confirmationMessage: String {
        switch self {
        case .clearAllMeals: return "This will remove all meals from the current week. This action cannot be undone."
        case .copyFromLastWeek: return "This will replace any existing meals in the current week with meals from last week."
        case .duplicateToNextWeek: return "This will copy all meals from this week to next week, replacing any existing meals."
        default: return "Are you sure you want to continue?"
        }
    }

    var actionTitle: String {
        switch self {
        case .clearAllMeals: return "Clear All"
        case .copyFromLastWeek: return "Copy Meals"
        case .duplicateToNextWeek: return "Duplicate Week"
        default: return "Confirm"
        }
    }

    var isDestructive: Bool {
        switch self {
        case .clearAllMeals: return true
        default: return false
        }
    }

    @MainActor func isAvailable(for store: MealPlanStore) -> Bool {
        switch self {
        case .copyFromLastWeek:
            // Check if there's a previous week plan stored locally
            let calendar = Calendar.current
            let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: store.selectedWeekStartDate) ?? store.selectedWeekStartDate
            // Check if there's stored meal data for the previous week
            let normalizedLastWeekStart = store.localStorageService.normalizeWeekStartDate(lastWeekStart)
            if let previousWeekGrid = store.localStorageService.loadMealPlan(for: normalizedLastWeekStart) {
                return previousWeekGrid.hasAnyMeals
            }
            return false
        case .clearAllMeals:
            // Can clear meals if current week has any meals
            return store.weeklyGrid.hasAnyMeals
        case .duplicateToNextWeek:
            // Can duplicate if current week has any meals
            return store.weeklyGrid.hasAnyMeals
        }
    }
}