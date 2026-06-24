//
//  MealPlanStore+AIGeneration.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 8/3/25.
//  AI meal plan generation functionality extension.
//

import Foundation

// MARK: - AI Generation Extension
extension MealPlanStore {

    // MARK: - AI Meal Plan Generation

    /// Generate a weekly meal plan with AI and show preview
    func generateWeeklyMealPlan(
        description: String,
        dietType: DietType? = nil,
        allergies: [String] = [],
        dislikes: [String] = [],
        calorieTarget: Int? = nil,
        additionalRequirements: String? = nil
    ) async {
        // Prepare generation request
        let request = AIGenerationRequest(
            description: description,
            dietType: dietType,
            allergies: allergies,
            dislikes: dislikes,
            calorieTarget: calorieTarget,
            // weekStartDate parameter removed
            additionalRequirements: additionalRequirements
        )

        // Delegate to AI generation service
        await aiGenerationService.generateAIMealPlan(request: request)
    }

    /// Confirm and apply the preview meal plan to current week with full Recipe generation
    func confirmPreviewMealPlan() async {
        print("🚀 [MealPlanStore] confirmPreviewMealPlan called - starting batch Recipe generation")

        // Extract RecipeStubs from the original AI-generated meal plan
        guard let originalMealPlan = aiGenerationService.previewMealPlan,
              let lightweightDailyMeals = originalMealPlan.lightweightDailyMeals else {
            print("❌ [MealPlanStore] No original meal plan or lightweight daily meals available")
            return
        }

        // Collect all RecipeStubs from the meal plan
        let allRecipeStubs = lightweightDailyMeals.flatMap { dailyMeal in
            dailyMeal.breakfast + dailyMeal.lunch + dailyMeal.dinner
        }

        print("🔍 [MealPlanStore] Extracted \(allRecipeStubs.count) RecipeStubs for batch generation")

        do {
            // Batch generate full Recipes using create-recipe-from-ai API
            let generatedRecipes = try await aiGenerationService.batchCreateRecipesFromStubs(allRecipeStubs)

            print("✅ [MealPlanStore] Successfully generated \(generatedRecipes.count) full Recipes")

            // Create a mapping from RecipeStub ID to generated Recipe
            let recipeMapping = Dictionary(uniqueKeysWithValues:
                zip(allRecipeStubs.map { $0.id }, generatedRecipes)
            )

            // Build new WeeklyMealGrid with generated full Recipes for the selected week
            var enhancedGrid = WeeklyMealGrid(weekStartDate: selectedWeekStartDate)

            for (dayIndex, lightweightDailyMeal) in lightweightDailyMeals.enumerated() {
                if dayIndex < enhancedGrid.dailyMeals.count {
                    // Map RecipeStubs to full Recipes using the mapping
                    let breakfastRecipes = lightweightDailyMeal.breakfast.compactMap { stub in
                        recipeMapping[stub.id] ?? stub.toRecipe() // Fallback to basic recipe if mapping fails
                    }
                    let lunchRecipes = lightweightDailyMeal.lunch.compactMap { stub in
                        recipeMapping[stub.id] ?? stub.toRecipe() // Fallback to basic recipe if mapping fails
                    }
                    let dinnerRecipes = lightweightDailyMeal.dinner.compactMap { stub in
                        recipeMapping[stub.id] ?? stub.toRecipe() // Fallback to basic recipe if mapping fails
                    }

                    // Apply generated Recipes to grid
                    enhancedGrid.dailyMeals[dayIndex].breakfast = breakfastRecipes
                    enhancedGrid.dailyMeals[dayIndex].lunch = lunchRecipes
                    enhancedGrid.dailyMeals[dayIndex].dinner = dinnerRecipes

                    print("📅 [MealPlanStore] Day \(dayIndex): \(breakfastRecipes.count) breakfast, \(lunchRecipes.count) lunch, \(dinnerRecipes.count) dinner recipes applied")
                }
            }

            // Apply the enhanced meal plan to current weekly grid
            weeklyGrid = enhancedGrid

            // Cache the generated recipes in RecipeStore for better performance
            await cacheGeneratedRecipes(generatedRecipes)

            // Save to local storage
            let saveResult = saveLocalMealPlan()
            if case .failure = saveResult {
                print("❌ [MealPlanStore] Failed to save confirmed meal plan")
            } else {
                print("✅ [MealPlanStore] Enhanced meal plan with full Recipes saved successfully")
            }

            // Update UI state
            showingGenerationView = false

        } catch {
            print("❌ [MealPlanStore] Batch recipe generation failed: \(error)")

            // Fallback to basic confirmation without AI enhancement
            guard let confirmedGrid = await aiGenerationService.confirmAIGeneration() else {
                print("❌ [MealPlanStore] Failed to confirm AI generation with fallback")
                return
            }

            var selectedWeekGrid = WeeklyMealGrid(weekStartDate: selectedWeekStartDate)
            for dayIndex in 0..<min(confirmedGrid.dailyMeals.count, selectedWeekGrid.dailyMeals.count) {
                selectedWeekGrid.dailyMeals[dayIndex].breakfast = confirmedGrid.dailyMeals[dayIndex].breakfast
                selectedWeekGrid.dailyMeals[dayIndex].lunch = confirmedGrid.dailyMeals[dayIndex].lunch
                selectedWeekGrid.dailyMeals[dayIndex].dinner = confirmedGrid.dailyMeals[dayIndex].dinner
            }

            weeklyGrid = selectedWeekGrid
            showingGenerationView = false
        }
    }

    /// Cache generated recipes in RecipeStore for better performance
    private func cacheGeneratedRecipes(_ recipes: [Recipe]) async {
        print("📦 [MealPlanStore] Starting to cache \(recipes.count) generated recipes")

        guard !recipes.isEmpty else {
            print("⚠️ [MealPlanStore] No recipes to cache")
            return
        }

        // Access the shared RecipeStore instance if available
        // Note: We need to access RecipeStore through the app's dependency injection
        // For now, we'll use the MultiTierCacheManager directly and let RecipeStore handle individual recipes

        // Generate a cache key for this batch of AI-generated recipes
        let cacheKey = "ai_generated_recipes_\(Date().timeIntervalSince1970)"

        // Store recipes in the multi-tier cache system
        let cacheManager = MultiTierCacheManager()
        cacheManager.cacheRecipes(recipes, forKey: cacheKey)

        // Also cache individual recipes for quick lookup
        for recipe in recipes {
            let individualKey = "recipe_\(recipe.id)"
            cacheManager.store(recipe, forKey: individualKey, ttl: 86400) // 24 hour TTL for individual recipes

            print("📦 [MealPlanStore] Cached individual recipe: \(recipe.name) (ID: \(recipe.id))")
        }

        print("✅ [MealPlanStore] Successfully cached \(recipes.count) AI-generated recipes")
    }

    /// Cancel AI generation and reset state
    func cancelAIGeneration() {
        aiGenerationService.cancelAIGeneration()
        showingGenerationView = false
    }

    /// Reset AI generation state
    func resetAIGenerationState() {
        aiGenerationService.resetAIGenerationState()
    }

    // MARK: - AI Generation Workflow Management

    func startAIGenerationWorkflow() {
        showingGenerationView = true
        resetAIGenerationState()
    }

    func exitAIGenerationWorkflow() {
        showingGenerationView = false
        cancelAIGeneration()
    }

    // MARK: - AI Generation State Computed Properties

    var canStartAIGeneration: Bool {
        aiGenerationService.canStartGeneration
    }

    var canPreviewAIGeneration: Bool {
        aiGenerationService.canPreview
    }

    var canConfirmAIGeneration: Bool {
        aiGenerationService.canConfirm
    }

    var isInAIGenerationFlow: Bool {
        aiGenerationService.isInGenerationFlow
    }

    var aiGenerationError: String? {
        aiGenerationService.aiGenerationError
    }

    // MARK: - Legacy AI Generation Method (for compatibility)

    func generateCustomMealPlan(
        description: String,
        dietType: DietType? = nil,
        allergies: [String] = [],
        dislikes: [String] = [],
        calorieTarget: Int? = nil,
        // weekStartDate parameter removed
        additionalRequirements: String? = nil
    ) async -> Bool {
        print("🔄 [MealPlanStore] Starting generateCustomMealPlan with description: '\(description)'")

        await generateWeeklyMealPlan(
            description: description,
            dietType: dietType,
            allergies: allergies,
            dislikes: dislikes,
            calorieTarget: calorieTarget,
            additionalRequirements: additionalRequirements
        )

        // Return success if we have a preview available
        return aiGenerationService.canPreview
    }
}

// MARK: - Supporting Types
// Note: AIGenerationRequest is defined in AIWorkflowCoordinator.swift