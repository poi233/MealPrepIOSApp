//
//  MealPlanStore+Analysis.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 8/3/25.
//  Shopping list and nutrition analysis integration extension.
//

import Foundation

// MARK: - Analysis and Shopping Extension
extension MealPlanStore {

    // MARK: - Shopping List Integration

    func generateShoppingList() async {
        await shoppingListService.generateShoppingList(from: weeklyGrid)
    }

    func toggleShoppingListItem(_ item: ShoppingListItem) {
        shoppingListService.toggleShoppingListItem(item)
    }

    func removeShoppingListItem(_ item: ShoppingListItem) {
        shoppingListService.removeShoppingListItem(item)
    }

    func addCustomShoppingListItem(name: String, amount: String = "", unit: String = "") {
        shoppingListService.addCustomShoppingListItem(name: name, amount: amount, unit: unit)
    }

    func clearShoppingList() {
        shoppingListService.clearShoppingList()
    }

    // MARK: - Nutrition Analysis Integration

    func analyzeNutrition() async {
        showingAnalysisView = true
        await nutritionAnalysisService.analyzeNutrition(from: weeklyGrid)
    }

    func analyzeCurrentMealPlan() async {
        await analyzeNutrition()
    }

    func clearNutritionAnalysis() {
        nutritionAnalysisService.clearNutritionAnalysis()
        showingAnalysisView = false
    }

    func calculateDailyNutrition(for dayIndex: Int) -> NutritionInfo? {
        return nutritionAnalysisService.calculateDailyNutrition(for: dayIndex, from: weeklyGrid)
    }

    func calculateWeeklyNutrition() -> NutritionInfo {
        return nutritionAnalysisService.calculateWeeklyNutrition(from: weeklyGrid)
    }

    func calculateAverageDailyNutrition() -> NutritionInfo {
        return nutritionAnalysisService.calculateAverageDailyNutrition(from: weeklyGrid)
    }

    // MARK: - Quick Analysis

    func getWeekSummary() -> WeekSummary {
        let allRecipes = getAllRecipesForWeek()
        let uniqueRecipes = getAllUniqueRecipesForWeek()
        let totalNutrition = calculateWeeklyNutrition()
        let averageNutrition = calculateAverageDailyNutrition()

        // Convert string nutrition values to numbers
        let totalCalories = Int(totalNutrition.calories ?? "0") ?? 0
        let averageCalories = Int(averageNutrition.calories ?? "0") ?? 0
        let totalProtein = Double(totalNutrition.protein ?? "0") ?? 0.0
        let averageProtein = Double(averageNutrition.protein ?? "0") ?? 0.0

        return WeekSummary(
            totalMeals: allRecipes.count,
            uniqueRecipes: uniqueRecipes.count,
            totalCalories: totalCalories,
            averageDailyCalories: averageCalories,
            totalProtein: totalProtein,
            averageDailyProtein: averageProtein,
            completedDays: getCompletedDaysCount(),
            plannedDays: getPlannedDaysCount()
        )
    }

    func getDaySummary(for dayIndex: Int) -> DaySummary? {
        guard dayIndex < weeklyGrid.dailyMeals.count else { return nil }

        let dayMeals = weeklyGrid.dailyMeals[dayIndex]
        let nutrition = calculateDailyNutrition(for: dayIndex) ?? NutritionInfo(
            calories: "0", protein: "0", carbohydrates: "0", fat: "0",
            fiber: "0", sodium: "0", sugar: "0", servings: 0
        )

        var mealsCount = 0
        var recipeNames: [String] = []

        // Count recipes in breakfast, lunch, dinner
        mealsCount += dayMeals.breakfast.count
        mealsCount += dayMeals.lunch.count
        mealsCount += dayMeals.dinner.count

        // Collect recipe names
        recipeNames.append(contentsOf: dayMeals.breakfast.map { $0.name })
        recipeNames.append(contentsOf: dayMeals.lunch.map { $0.name })
        recipeNames.append(contentsOf: dayMeals.dinner.map { $0.name })

        // Convert string nutrition values to numbers
        let totalCalories = Int(nutrition.calories ?? "0") ?? 0
        let totalProtein = Double(nutrition.protein ?? "0") ?? 0.0

        return DaySummary(
            dayIndex: dayIndex,
            mealsCount: mealsCount,
            recipeNames: recipeNames,
            totalCalories: totalCalories,
            totalProtein: totalProtein,
            isComplete: !dayMeals.breakfast.isEmpty && !dayMeals.lunch.isEmpty && !dayMeals.dinner.isEmpty // All main meals planned
        )
    }

    private func getCompletedDaysCount() -> Int {
        var completedDays = 0

        for dayIndex in 0..<min(7, weeklyGrid.dailyMeals.count) {
            let dayMeals = weeklyGrid.dailyMeals[dayIndex]

            // Check if all main meals are planned (at least one recipe in each)
            if !dayMeals.breakfast.isEmpty && !dayMeals.lunch.isEmpty && !dayMeals.dinner.isEmpty {
                completedDays += 1
            }
        }

        return completedDays
    }

    private func getPlannedDaysCount() -> Int {
        var plannedDays = 0

        for dayIndex in 0..<min(7, weeklyGrid.dailyMeals.count) {
            let dayMeals = weeklyGrid.dailyMeals[dayIndex]

            // Check if any meal is planned (at least one recipe in any meal slot)
            if !dayMeals.breakfast.isEmpty || !dayMeals.lunch.isEmpty || !dayMeals.dinner.isEmpty {
                plannedDays += 1
            }
        }

        return plannedDays
    }

    // MARK: - Shopping List Computed Properties

    var completedShoppingItems: [ShoppingListItem] {
        shoppingListService.completedItems
    }

    var pendingShoppingItems: [ShoppingListItem] {
        shoppingListService.pendingItems
    }

    var groupedShoppingList: [String: [ShoppingListItem]] {
        shoppingListService.groupedShoppingList
    }

    var totalShoppingItemsCount: Int {
        shoppingListService.totalItemsCount
    }

    var completedShoppingItemsCount: Int {
        shoppingListService.completedItemsCount
    }

    var shoppingCompletionPercentage: Double {
        shoppingListService.completionPercentage
    }
}

// MARK: - Supporting Types

struct WeekSummary {
    let totalMeals: Int
    let uniqueRecipes: Int
    let totalCalories: Int
    let averageDailyCalories: Int
    let totalProtein: Double
    let averageDailyProtein: Double
    let completedDays: Int
    let plannedDays: Int

    var completionPercentage: Double {
        guard plannedDays > 0 else { return 0 }
        return Double(completedDays) / Double(plannedDays)
    }

    var planningPercentage: Double {
        return Double(plannedDays) / 7.0
    }
}

struct DaySummary {
    let dayIndex: Int
    let mealsCount: Int
    let recipeNames: [String]
    let totalCalories: Int
    let totalProtein: Double
    let isComplete: Bool

    var dayName: String {
        let calendar = Calendar.mondayFirst
        let dayNames = calendar.weekdaySymbols
        let adjustedIndex = (dayIndex + 1) % 7 // Convert Monday-first to Sunday-first
        return dayNames[adjustedIndex]
    }

    var shortDayName: String {
        let calendar = Calendar.mondayFirst
        let dayNames = calendar.shortWeekdaySymbols
        let adjustedIndex = (dayIndex + 1) % 7 // Convert Monday-first to Sunday-first
        return dayNames[adjustedIndex]
    }
}

// MARK: - Extensions
// Note: MealType.displayName extension is already defined in SharedEnums.swift