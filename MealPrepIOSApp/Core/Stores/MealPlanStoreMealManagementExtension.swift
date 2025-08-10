//
//  MealPlanStore+MealManagement.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 8/3/25.
//  Meal management and CRUD operations extension.
//

import Foundation

// MARK: - Meal Management Extension
extension MealPlanStore {

    // MARK: - Weekly Grid Management

    func navigateToWeek(_ direction: WeekDirection) async {
        switch direction {
        case .previous:
            navigateToPreviousWeek()
        case .next:
            navigateToNextWeek()
        case .current:
            selectCurrentWeek()
        }
    }

    func navigateToPreviousWeek() {
        guard canNavigateToPreviousWeek else { return }

        let calendar = Calendar.mondayFirst
        if let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedWeekStartDate) {
            selectWeek(previousWeek)
        }
    }

    func navigateToNextWeek() {
        guard canNavigateToNextWeek else { return }

        let calendar = Calendar.mondayFirst
        if let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedWeekStartDate) {
            selectWeek(nextWeek)
        }
    }

    func selectWeek(_ weekStartDate: Date) {
        let normalizedDate = localStorageService.normalizeWeekStartDate(weekStartDate)

        // Only change if different
        guard !Calendar.mondayFirst.isDate(normalizedDate, equalTo: selectedWeekStartDate, toGranularity: .day) else {
            return
        }

        // Save current week before switching
        _ = saveLocalMealPlan()

        // Update selected week
        selectedWeekStartDate = normalizedDate

        // Load meal plan for new week
        loadLocalMealPlan()

        print("📅 [MealPlanStore] Selected week: \\(localStorageService.formatWeekDate(normalizedDate))")
    }

    func selectCurrentWeek() {
        let currentWeekStart = Date().startOfWeek()
        selectWeek(currentWeekStart)
    }

    // MARK: - Meal CRUD Operations

    func addMeal(_ recipe: Recipe, to dayIndex: Int, mealType: MealType) {
        guard dayIndex < weeklyGrid.dailyMeals.count else { return }

        switch mealType {
        case .breakfast:
            weeklyGrid.dailyMeals[dayIndex].breakfast.append(recipe)
        case .lunch:
            weeklyGrid.dailyMeals[dayIndex].lunch.append(recipe)
        case .dinner:
            weeklyGrid.dailyMeals[dayIndex].dinner.append(recipe)
        }

        // Add to recent meals
        addToRecentMeals(recipe)

        // Save changes
        _ = saveLocalMealPlan()

        print("✅ [MealPlanStore] Added meal: \\(recipe.name) to \\(mealType.displayName)")
    }

    func updateMeal(_ recipe: Recipe, at dayIndex: Int, mealType: MealType, position: Int = 0) {
        guard dayIndex < weeklyGrid.dailyMeals.count else { return }

        switch mealType {
        case .breakfast:
            if position < weeklyGrid.dailyMeals[dayIndex].breakfast.count {
                weeklyGrid.dailyMeals[dayIndex].breakfast[position] = recipe
            }
        case .lunch:
            if position < weeklyGrid.dailyMeals[dayIndex].lunch.count {
                weeklyGrid.dailyMeals[dayIndex].lunch[position] = recipe
            }
        case .dinner:
            if position < weeklyGrid.dailyMeals[dayIndex].dinner.count {
                weeklyGrid.dailyMeals[dayIndex].dinner[position] = recipe
            }
        }

        // Save changes
        _ = saveLocalMealPlan()

        print("🔄 [MealPlanStore] Updated meal: \\(recipe.name) at \\(mealType.displayName)")
    }

    func removeMeal(from dayIndex: Int, mealType: MealType, position: Int = 0) {
        guard dayIndex < weeklyGrid.dailyMeals.count else { return }

        switch mealType {
        case .breakfast:
            if position < weeklyGrid.dailyMeals[dayIndex].breakfast.count {
                weeklyGrid.dailyMeals[dayIndex].breakfast.remove(at: position)
            }
        case .lunch:
            if position < weeklyGrid.dailyMeals[dayIndex].lunch.count {
                weeklyGrid.dailyMeals[dayIndex].lunch.remove(at: position)
            }
        case .dinner:
            if position < weeklyGrid.dailyMeals[dayIndex].dinner.count {
                weeklyGrid.dailyMeals[dayIndex].dinner.remove(at: position)
            }
        }

        // Save changes
        _ = saveLocalMealPlan()

        print("🗑️ [MealPlanStore] Removed meal from \\(mealType.displayName)")
    }

    func clearMealType(dayIndex: Int, mealType: MealType) {
        guard dayIndex < weeklyGrid.dailyMeals.count else { return }

        switch mealType {
        case .breakfast:
            weeklyGrid.dailyMeals[dayIndex].breakfast.removeAll()
        case .lunch:
            weeklyGrid.dailyMeals[dayIndex].lunch.removeAll()
        case .dinner:
            weeklyGrid.dailyMeals[dayIndex].dinner.removeAll()
        }

        // Save changes
        _ = saveLocalMealPlan()

        print("🧹 [MealPlanStore] Cleared all meals from \\(mealType.displayName)")
    }

    // MARK: - Batch Operations

    func clearWeek() {
        weeklyGrid = WeeklyMealGrid()

        // Save changes
        _ = saveLocalMealPlan()

        print("🧹 [MealPlanStore] Cleared all meals for current week")
    }

    func copyFromPreviousWeek() {
        let calendar = Calendar.mondayFirst
        guard let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedWeekStartDate),
              isWithinAllowedWeekRange(previousWeekStart) else {
            print("❌ [MealPlanStore] Cannot copy from previous week - out of range")
            return
        }

        if let previousWeekGrid = localStorageService.loadMealPlan(for: previousWeekStart) {
            // Create a new grid with current week's date but previous week's meals
            weeklyGrid = WeeklyMealGrid()

            // Copy meals
            for dayIndex in 0..<min(7, previousWeekGrid.dailyMeals.count, weeklyGrid.dailyMeals.count) {
                weeklyGrid.dailyMeals[dayIndex].breakfast = previousWeekGrid.dailyMeals[dayIndex].breakfast
                weeklyGrid.dailyMeals[dayIndex].lunch = previousWeekGrid.dailyMeals[dayIndex].lunch
                weeklyGrid.dailyMeals[dayIndex].dinner = previousWeekGrid.dailyMeals[dayIndex].dinner
            }

            // Save changes
            _ = saveLocalMealPlan()

            print("📋 [MealPlanStore] Copied meals from previous week")
        } else {
            print("❌ [MealPlanStore] No meal plan found for previous week")
        }
    }

    func duplicateToNextWeek() {
        let calendar = Calendar.mondayFirst
        guard let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedWeekStartDate),
              isWithinAllowedWeekRange(nextWeekStart) else {
            print("❌ [MealPlanStore] Cannot duplicate to next week - out of range")
            return
        }

        // Create new grid for next week with current week's meals
        var nextWeekGrid = WeeklyMealGrid()

        // Copy meals
        for dayIndex in 0..<min(7, weeklyGrid.dailyMeals.count, nextWeekGrid.dailyMeals.count) {
            nextWeekGrid.dailyMeals[dayIndex].breakfast = weeklyGrid.dailyMeals[dayIndex].breakfast
            nextWeekGrid.dailyMeals[dayIndex].lunch = weeklyGrid.dailyMeals[dayIndex].lunch
            nextWeekGrid.dailyMeals[dayIndex].dinner = weeklyGrid.dailyMeals[dayIndex].dinner
        }

        // Save to next week
        let saveResult = localStorageService.saveMealPlan(nextWeekGrid)
        if case .success = saveResult {
            print("📋 [MealPlanStore] Duplicated current week to next week")
        } else {
            print("❌ [MealPlanStore] Failed to duplicate to next week")
        }
    }

    // MARK: - Legacy API Compatibility (for MealActionSheet and other views)

    func updateMealServingSize(mealPlanItem: MealPlanItem, newServingSize: Double) async {
        // For now, this is a placeholder as serving size handling needs more complex implementation
        print("🔄 [MealPlanStore] Update serving size for meal: \(mealPlanItem.recipe?.name ?? "Unknown") to \(newServingSize)")
        // TODO: Implement serving size adjustments when proper nutrition scaling is available
    }

    func duplicateMeal(mealPlanItem: MealPlanItem, toDayOfWeek: Int, toMealType: MealType) async {
        guard toDayOfWeek < weeklyGrid.dailyMeals.count,
              let recipe = mealPlanItem.recipe else { return }

        addMeal(recipe, to: toDayOfWeek, mealType: toMealType)

        print("📋 [MealPlanStore] Duplicated meal: \(recipe.name) to day \(toDayOfWeek), \(toMealType.displayName)")
    }

    func removeMealFromPlan(mealPlanItem: MealPlanItem) async {
        let dayIndex = mealPlanItem.dayOfWeek
        let mealType = MealType(rawValue: mealPlanItem.mealType) ?? .breakfast

        // Find and remove the specific recipe
        guard dayIndex < weeklyGrid.dailyMeals.count,
              let recipe = mealPlanItem.recipe else { return }

        switch mealType {
        case .breakfast:
            if let index = weeklyGrid.dailyMeals[dayIndex].breakfast.firstIndex(where: { $0.id == recipe.id }) {
                weeklyGrid.dailyMeals[dayIndex].breakfast.remove(at: index)
            }
        case .lunch:
            if let index = weeklyGrid.dailyMeals[dayIndex].lunch.firstIndex(where: { $0.id == recipe.id }) {
                weeklyGrid.dailyMeals[dayIndex].lunch.remove(at: index)
            }
        case .dinner:
            if let index = weeklyGrid.dailyMeals[dayIndex].dinner.firstIndex(where: { $0.id == recipe.id }) {
                weeklyGrid.dailyMeals[dayIndex].dinner.remove(at: index)
            }
        }

        // Save changes
        _ = saveLocalMealPlan()

        print("🗑️ [MealPlanStore] Removed meal: \(recipe.name) from day \(dayIndex), \(mealType.displayName)")
    }

    func moveMeal(from mealPlanItem: MealPlanItem, toDayOfWeek: Int, toMealType: MealType) async {
        guard let recipe = mealPlanItem.recipe else { return }

        // First remove from current location
        await removeMealFromPlan(mealPlanItem: mealPlanItem)

        // Then add to new location
        guard toDayOfWeek < weeklyGrid.dailyMeals.count else { return }
        addMeal(recipe, to: toDayOfWeek, mealType: toMealType)

        print("📦 [MealPlanStore] Moved meal: \(recipe.name) to day \(toDayOfWeek), \(toMealType.displayName)")
    }

    // MARK: - Convenience Methods

    func getMeals(dayIndex: Int, mealType: MealType) -> [Recipe] {
        guard dayIndex < weeklyGrid.dailyMeals.count else { return [] }

        switch mealType {
        case .breakfast:
            return weeklyGrid.dailyMeals[dayIndex].breakfast
        case .lunch:
            return weeklyGrid.dailyMeals[dayIndex].lunch
        case .dinner:
            return weeklyGrid.dailyMeals[dayIndex].dinner
        }
    }

    func hasMeal(dayIndex: Int, mealType: MealType) -> Bool {
        return !getMeals(dayIndex: dayIndex, mealType: mealType).isEmpty
    }

    func getFirstRecipe(dayIndex: Int, mealType: MealType) -> Recipe? {
        let meals = getMeals(dayIndex: dayIndex, mealType: mealType)
        return meals.first
    }

    // Note: getAllRecipesForWeek() and getAllUniqueRecipesForWeek() are now defined in MealPlanStore.swift
}