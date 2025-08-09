//
//  MealPlanStore+Loading.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 8/3/25.
//  Meal plan loading functionality extension.
//

import Foundation

// MARK: - Meal Plan Loading Extension
extension MealPlanStore {

    // MARK: - Meal Plan Loading

    func loadMealPlans(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            mealPlans = []
        }

        isLoading = !refresh && mealPlans.isEmpty

        do {
            let response = try await mealPlanService.getMealPlans(page: currentPage, pageSize: pageSize)

            if refresh || currentPage == 1 {
                mealPlans = response.results
            } else {
                mealPlans.append(contentsOf: response.results)
            }

            totalPages = response.totalPages
            totalCount = response.count
            hasMorePages = response.next != nil

            // Set current meal plan if none selected
            if currentMealPlan == nil && !mealPlans.isEmpty {
                currentMealPlan = mealPlans.first
            }

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func loadMoreMealPlans() async {
        guard hasMorePages && !isLoading else { return }

        currentPage += 1
        await loadMealPlans()
    }

    func refreshMealPlans() async {
        await loadMealPlans(refresh: true)
    }

    func loadMealPlan(id: String) async {
        isLoading = true

        do {
            currentMealPlan = try await mealPlanService.getMealPlan(id: id)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    // MARK: - Recent Meals Management

    func loadRecentMeals() async {
        do {
            recentMeals = try await mealPlanService.getRecentMeals(limit: 10)
        } catch {
            print("❌ [MealPlanStore] Failed to load recent meals: \\(error)")
        }
    }

    func addToRecentMeals(_ recipe: Recipe) {
        // Remove if already exists to avoid duplicates
        recentMeals.removeAll { $0.id == recipe.id }

        // Add to beginning
        recentMeals.insert(recipe, at: 0)

        // Keep only last 10
        if recentMeals.count > 10 {
            recentMeals = Array(recentMeals.prefix(10))
        }
    }

    // MARK: - AI Recommendations

    func loadAIRecommendations() async {
        do {
            aiRecommendedRecipes = try await mealPlanService.getAIRecommendations(limit: 5)
        } catch {
            print("❌ [MealPlanStore] Failed to load AI recommendations: \\(error)")
        }
    }

    func refreshAIRecommendations() async {
        await loadAIRecommendations()
    }

    // MARK: - Week Management Methods (for compatibility with existing views)

    func addMealToWeek(recipe: Recipe, dayOfWeek: Int, mealType: MealType, servingSize: Double = 1.0) async {
        // Use the new addMeal method from MealManagement extension
        addMeal(recipe, to: dayOfWeek, mealType: mealType)

        // Add to recent meals
        addToRecentMeals(recipe)

        print("✅ [MealPlanStore] Added meal to week: \\(recipe.name)")
    }

    func addCustomMealToWeek(name: String, calories: Double, dayOfWeek: Int, mealType: MealType) async {
        // Create a temporary custom recipe
        let customRecipe = Recipe(
            id: UUID().uuidString,
            name: name,
            description: "Custom meal",
            ingredients: [],
            instructions: [],
            nutritionInfo: NutritionInfo(
                calories: String(Int(calories)),
                protein: "0",
                carbohydrates: "0",
                fat: "0",
                fiber: "0",
                sodium: "0",
                sugar: "0",
                servings: 1
            ),
            cuisine: nil,
            prepTime: 0,
            cookTime: 0,
            difficulty: .easy,
            avgRating: 0.0,
            ratingCount: 0,
            imageUrl: nil,
            tags: ["custom"],
            createdByUser: "custom",
            createdByUserId: "",
            createdAt: Date(),
            updatedAt: Date()
        )

        await addMealToWeek(recipe: customRecipe, dayOfWeek: dayOfWeek, mealType: mealType)
    }

    func loadAIRecommendations(for mealType: MealType) async {
        // Load general AI recommendations (mealType parameter ignored for now)
        await loadAIRecommendations()
    }
}