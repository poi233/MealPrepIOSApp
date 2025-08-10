//
//  NutritionAnalysisService.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 8/3/25.
//  Extracted from MealPlanStore.swift for better separation of concerns.
//

import SwiftUI
import Combine

// MARK: - Nutrition Analysis Service
@MainActor
class NutritionAnalysisService: ObservableObject {
    @Published var nutritionAnalysis: MealPlanAnalysis?
    @Published var isAnalyzing = false

    private let mealPlanService = MealPlanService()

    // MARK: - Nutrition Analysis

    func analyzeNutrition(from weeklyGrid: WeeklyMealGrid) async {
        isAnalyzing = true

        do {
            // Try backend analysis first
            let backendAnalysis = try await performBackendAnalysis(weeklyGrid: weeklyGrid)
            nutritionAnalysis = backendAnalysis
            print("✅ [NutritionAnalysisService] Backend nutrition analysis completed")
        } catch {
            print("⚠️ [NutritionAnalysisService] Backend failed, using local analysis: \(error)")
            
            // Local fallback analysis
            let localAnalysis = performLocalAnalysis(weeklyGrid: weeklyGrid)
            nutritionAnalysis = localAnalysis
            print("✅ [NutritionAnalysisService] Local nutrition analysis completed")
        }

        isAnalyzing = false
    }
    
    private func performBackendAnalysis(weeklyGrid: WeeklyMealGrid) async throws -> MealPlanAnalysis {
        // Create a temporary meal plan for backend analysis
        let mealPlan = createTemporaryMealPlan(from: weeklyGrid)
        return try await mealPlanService.analyzeMealPlan(id: mealPlan.id, analysisType: .nutrition)
    }
    
    private func performLocalAnalysis(weeklyGrid: WeeklyMealGrid) -> MealPlanAnalysis {
        let weeklyNutrition = calculateWeeklyNutrition(from: weeklyGrid)
        let dailyAverage = calculateAverageDailyNutrition(from: weeklyGrid)
        let totalRecipes = countRecipes(in: weeklyGrid)
        let uniqueRecipes = countUniqueRecipes(in: weeklyGrid)
        
        // Generate comprehensive analysis text
        let analysisText = generateNutritionAnalysisText(
            weeklyNutrition: weeklyNutrition,
            dailyAverage: dailyAverage,
            totalRecipes: totalRecipes,
            uniqueRecipes: uniqueRecipes,
            weeklyGrid: weeklyGrid
        )
        
        return MealPlanAnalysis(
            mealPlanId: "local_analysis",
            analysisType: .nutrition,
            totalRecipes: totalRecipes,
            analysisText: analysisText,
            analysisDate: Date()
        )
    }

    private func countRecipes(in weeklyGrid: WeeklyMealGrid) -> Int {
        var count = 0
        for dayMeals in weeklyGrid.dailyMeals {
            count += dayMeals.breakfast.count
            count += dayMeals.lunch.count
            count += dayMeals.dinner.count
        }
        return count
    }

    func clearNutritionAnalysis() {
        nutritionAnalysis = nil
    }
    
    // MARK: - Helper Methods
    
    private func createTemporaryMealPlan(from weeklyGrid: WeeklyMealGrid) -> MealPlan {
        // Convert weekly grid to meal plan items for backend analysis
        var items: [MealPlanItem] = []
        
        for (dayIndex, dayMeals) in weeklyGrid.dailyMeals.enumerated() {
            // Add breakfast items
            for recipe in dayMeals.breakfast {
                let item = MealPlanItem(
                    id: nil,
                    mealPlanId: nil,
                    recipe: recipe,
                    recipeId: recipe.id,
                    dayOfWeek: dayIndex,
                    mealType: "breakfast",
                    addedAt: Date()
                )
                items.append(item)
            }
            
            // Add lunch items
            for recipe in dayMeals.lunch {
                let item = MealPlanItem(
                    id: nil,
                    mealPlanId: nil,
                    recipe: recipe,
                    recipeId: recipe.id,
                    dayOfWeek: dayIndex,
                    mealType: "lunch",
                    addedAt: Date()
                )
                items.append(item)
            }
            
            // Add dinner items
            for recipe in dayMeals.dinner {
                let item = MealPlanItem(
                    id: nil,
                    mealPlanId: nil,
                    recipe: recipe,
                    recipeId: recipe.id,
                    dayOfWeek: dayIndex,
                    mealType: "dinner",
                    addedAt: Date()
                )
                items.append(item)
            }
        }
        
        return MealPlan(
            id: "temp_analysis_\(UUID().uuidString)",
            userId: nil,
            name: "Temporary Analysis Plan",
            description: "Generated for nutrition analysis",
            isActive: false,
            planDescription: nil,
            analysisText: nil,
            items: items,
            itemsCount: items.count,
            dailyMeals: nil,
            lightweightDailyMeals: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    private func countUniqueRecipes(in weeklyGrid: WeeklyMealGrid) -> Int {
        var uniqueRecipeIds: Set<String> = Set()
        
        for dayMeals in weeklyGrid.dailyMeals {
            for recipe in dayMeals.breakfast {
                uniqueRecipeIds.insert(recipe.id)
            }
            for recipe in dayMeals.lunch {
                uniqueRecipeIds.insert(recipe.id)
            }
            for recipe in dayMeals.dinner {
                uniqueRecipeIds.insert(recipe.id)
            }
        }
        
        return uniqueRecipeIds.count
    }
    
    private func generateNutritionAnalysisText(
        weeklyNutrition: NutritionInfo,
        dailyAverage: NutritionInfo,
        totalRecipes: Int,
        uniqueRecipes: Int,
        weeklyGrid: WeeklyMealGrid
    ) -> String {
        var analysisComponents: [String] = []
        
        // Overview
        analysisComponents.append("📊 **NUTRITION OVERVIEW**")
        analysisComponents.append("Total meals planned: \(totalRecipes)")
        analysisComponents.append("Unique recipes: \(uniqueRecipes)")
        analysisComponents.append("")
        
        // Weekly totals
        analysisComponents.append("🥪 **WEEKLY TOTALS**")
        analysisComponents.append("• Calories: \(weeklyNutrition.calories ?? "0") kcal")
        analysisComponents.append("• Protein: \(weeklyNutrition.protein ?? "0")g")
        analysisComponents.append("• Carbohydrates: \(weeklyNutrition.carbohydrates ?? "0")g")
        analysisComponents.append("• Fat: \(weeklyNutrition.fat ?? "0")g")
        analysisComponents.append("• Fiber: \(weeklyNutrition.fiber ?? "0")g")
        analysisComponents.append("")
        
        // Daily averages
        analysisComponents.append("📈 **DAILY AVERAGES**")
        analysisComponents.append("• Calories: \(dailyAverage.calories ?? "0") kcal/day")
        analysisComponents.append("• Protein: \(dailyAverage.protein ?? "0")g/day")
        analysisComponents.append("• Carbohydrates: \(dailyAverage.carbohydrates ?? "0")g/day")
        analysisComponents.append("• Fat: \(dailyAverage.fat ?? "0")g/day")
        analysisComponents.append("")
        
        // Analysis insights
        analysisComponents.append("🔍 **INSIGHTS & RECOMMENDATIONS**")
        
        let avgCalories = Int(dailyAverage.calories ?? "0") ?? 0
        if avgCalories < 1200 {
            analysisComponents.append("⚠️ Daily calories may be too low for most adults (< 1200 kcal)")
        } else if avgCalories > 2500 {
            analysisComponents.append("⚠️ Daily calories are quite high (> 2500 kcal)")
        } else {
            analysisComponents.append("✅ Daily calorie intake appears reasonable")
        }
        
        let avgProtein = Double(dailyAverage.protein ?? "0") ?? 0.0
        if avgProtein < 50 {
            analysisComponents.append("📈 Consider adding more protein sources (current: \(String(format: "%.1f", avgProtein))g/day)")
        } else {
            analysisComponents.append("✅ Protein intake looks adequate (\(String(format: "%.1f", avgProtein))g/day)")
        }
        
        // Meal distribution analysis
        let mealDistribution = analyzeMealDistribution(weeklyGrid: weeklyGrid)
        analysisComponents.append("")
        analysisComponents.append("🍽️ **MEAL DISTRIBUTION**")
        analysisComponents.append("• Breakfast planned: \(mealDistribution.breakfastDays)/7 days")
        analysisComponents.append("• Lunch planned: \(mealDistribution.lunchDays)/7 days")
        analysisComponents.append("• Dinner planned: \(mealDistribution.dinnerDays)/7 days")
        
        if mealDistribution.breakfastDays < 5 {
            analysisComponents.append("💡 Consider planning more breakfast meals")
        }
        
        // Recipe variety analysis
        let varietyScore = Double(uniqueRecipes) / max(Double(totalRecipes), 1.0)
        analysisComponents.append("")
        analysisComponents.append("🎨 **VARIETY ANALYSIS**")
        if varietyScore > 0.8 {
            analysisComponents.append("✅ Excellent variety! Most meals are unique recipes")
        } else if varietyScore > 0.6 {
            analysisComponents.append("👍 Good variety with some recipe repeats")
        } else {
            analysisComponents.append("📈 Consider adding more variety to your meal plan")
        }
        
        return analysisComponents.joined(separator: "\n")
    }
    
    private func analyzeMealDistribution(weeklyGrid: WeeklyMealGrid) -> (breakfastDays: Int, lunchDays: Int, dinnerDays: Int) {
        var breakfastDays = 0
        var lunchDays = 0
        var dinnerDays = 0
        
        for dayMeals in weeklyGrid.dailyMeals.prefix(7) {
            if !dayMeals.breakfast.isEmpty { breakfastDays += 1 }
            if !dayMeals.lunch.isEmpty { lunchDays += 1 }
            if !dayMeals.dinner.isEmpty { dinnerDays += 1 }
        }
        
        return (breakfastDays, lunchDays, dinnerDays)
    }

    // MARK: - Daily and Weekly Nutrition Calculation (Placeholder)

    func calculateDailyNutrition(for dayIndex: Int, from weeklyGrid: WeeklyMealGrid) -> NutritionInfo? {
        guard dayIndex < weeklyGrid.dailyMeals.count else { return nil }

        let dayMeals = weeklyGrid.dailyMeals[dayIndex]
        
        // Calculate nutrition based on actual recipe data where available
        var totalCalories = 0
        var totalProtein: Double = 0.0
        var totalCarbs = 0
        var totalFat = 0
        var totalFiber = 0
        var totalSodium = 0
        var totalSugar = 0
        var totalServings = 0
        
        // Helper function to extract nutrition from recipe or estimate
        func addNutritionFromRecipe(_ recipe: Recipe) {
            if let nutrition = recipe.nutritionInfo {
                // Use actual nutrition data if available
                totalCalories += Int(nutrition.calories ?? "0") ?? 0
                totalProtein += Double(nutrition.protein ?? "0") ?? 0.0
                totalCarbs += Int(nutrition.carbohydrates ?? "0") ?? 0
                totalFat += Int(nutrition.fat ?? "0") ?? 0
                totalFiber += Int(nutrition.fiber ?? "0") ?? 0
                totalSodium += Int(nutrition.sodium ?? "0") ?? 0
                totalSugar += Int(nutrition.sugar ?? "0") ?? 0
                totalServings += nutrition.servings ?? 1
            } else {
                // Fallback estimation based on recipe complexity and ingredients
                let ingredientCount = recipe.ingredients.count
                let complexityMultiplier = max(1, ingredientCount / 5) // More ingredients = more calories
                
                totalCalories += 250 * complexityMultiplier
                totalProtein += 12.0 * Double(complexityMultiplier)
                totalCarbs += 25 * complexityMultiplier
                totalFat += 8 * complexityMultiplier
                totalFiber += 4 * complexityMultiplier
                totalSodium += 180 * complexityMultiplier
                totalSugar += 6 * complexityMultiplier
                totalServings += 1
            }
        }
        
        // Process all meals for the day
        for recipe in dayMeals.breakfast { addNutritionFromRecipe(recipe) }
        for recipe in dayMeals.lunch { addNutritionFromRecipe(recipe) }
        for recipe in dayMeals.dinner { addNutritionFromRecipe(recipe) }

        return NutritionInfo(
            calories: String(totalCalories),
            protein: String(format: "%.1f", totalProtein),
            carbohydrates: String(totalCarbs),
            fat: String(totalFat),
            fiber: String(totalFiber),
            sodium: String(totalSodium),
            sugar: String(totalSugar),
            servings: totalServings
        )
    }

    func calculateWeeklyNutrition(from weeklyGrid: WeeklyMealGrid) -> NutritionInfo {
        var totalCalories = 0
        var totalProtein: Double = 0.0
        var totalCarbs = 0
        var totalFat = 0
        var totalFiber = 0
        var totalSodium = 0
        var totalSugar = 0
        var totalServings = 0
        
        // Sum up nutrition for each day
        for dayIndex in 0..<min(7, weeklyGrid.dailyMeals.count) {
            if let dayNutrition = calculateDailyNutrition(for: dayIndex, from: weeklyGrid) {
                totalCalories += Int(dayNutrition.calories ?? "0") ?? 0
                totalProtein += Double(dayNutrition.protein ?? "0") ?? 0.0
                totalCarbs += Int(dayNutrition.carbohydrates ?? "0") ?? 0
                totalFat += Int(dayNutrition.fat ?? "0") ?? 0
                totalFiber += Int(dayNutrition.fiber ?? "0") ?? 0
                totalSodium += Int(dayNutrition.sodium ?? "0") ?? 0
                totalSugar += Int(dayNutrition.sugar ?? "0") ?? 0
                totalServings += dayNutrition.servings ?? 0
            }
        }

        return NutritionInfo(
            calories: String(totalCalories),
            protein: String(format: "%.1f", totalProtein),
            carbohydrates: String(totalCarbs),
            fat: String(totalFat),
            fiber: String(totalFiber),
            sodium: String(totalSodium),
            sugar: String(totalSugar),
            servings: totalServings
        )
    }

    func calculateAverageDailyNutrition(from weeklyGrid: WeeklyMealGrid) -> NutritionInfo {
        let weeklyNutrition = calculateWeeklyNutrition(from: weeklyGrid)
        
        // Count days that have meals planned for more accurate averaging
        let daysWithMeals = weeklyGrid.dailyMeals.prefix(7).count { dayMeals in
            !dayMeals.breakfast.isEmpty || !dayMeals.lunch.isEmpty || !dayMeals.dinner.isEmpty
        }
        
        let divisor = max(daysWithMeals, 1) // Avoid division by zero

        // Convert strings to numbers, divide by actual days with meals, then convert back
        let avgCalories = (Int(weeklyNutrition.calories ?? "0") ?? 0) / divisor
        let avgProtein = (Double(weeklyNutrition.protein ?? "0") ?? 0.0) / Double(divisor)
        let avgCarbs = (Int(weeklyNutrition.carbohydrates ?? "0") ?? 0) / divisor
        let avgFat = (Int(weeklyNutrition.fat ?? "0") ?? 0) / divisor
        let avgFiber = (Int(weeklyNutrition.fiber ?? "0") ?? 0) / divisor
        let avgSodium = (Int(weeklyNutrition.sodium ?? "0") ?? 0) / divisor
        let avgSugar = (Int(weeklyNutrition.sugar ?? "0") ?? 0) / divisor
        let avgServings = (weeklyNutrition.servings ?? 0) / divisor

        return NutritionInfo(
            calories: String(avgCalories),
            protein: String(format: "%.1f", avgProtein),
            carbohydrates: String(avgCarbs),
            fat: String(avgFat),
            fiber: String(avgFiber),
            sodium: String(avgSodium),
            sugar: String(avgSugar),
            servings: avgServings
        )
    }
}