//
//  NotificationExtensions.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/26/25.
//

import Foundation

extension Notification.Name {
    /// Posted when a recipe is deleted from the backend
    static let recipeDeleted = Notification.Name("recipeDeleted")

    /// Posted when a user is logged in
    static let userLoggedIn = Notification.Name("userLoggedIn")

    /// Posted when a user is logged out
    static let userLoggedOut = Notification.Name("userLoggedOut")

    /// Posted when meal plan data needs to be refreshed
    static let mealPlanDataChanged = Notification.Name("mealPlanDataChanged")
}

/// User info keys for recipe deletion notifications
struct RecipeDeletionNotificationKeys {
    static let recipeId = "recipeId"
    static let recipeName = "recipeName"
}

/// User info keys for meal plan change notifications
struct MealPlanChangeNotificationKeys {
    static let mealPlanId = "mealPlanId"
    static let changeType = "changeType"
}

/// Types of meal plan changes
enum MealPlanChangeType: String {
    case created = "created"
    case updated = "updated"
    case deleted = "deleted"
}