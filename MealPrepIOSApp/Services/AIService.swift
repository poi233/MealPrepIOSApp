//
//  AIService.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import Foundation

// MARK: - AI Service
class AIService {
    private let networkManager = NetworkManager.shared

    // MARK: - AI Meal Plan Generation

    /// Generate a personalized meal plan using AI
    func generateMealPlan(_ request: GenerateMealPlanRequest) async throws -> MealPlan {
        return try await networkManager.post(
            "/ai/generate-meal-plan/",
            body: request,
            responseType: MealPlan.self,
            requiresAuth: true
        )
    }

    /// Generate recipe details using AI
    func generateRecipeDetails(_ request: GenerateRecipeDetailsRequest) async throws -> Recipe {
        return try await networkManager.post(
            "/ai/generate-recipe-details/",
            body: request,
            responseType: Recipe.self,
            requiresAuth: true
        )
    }

    /// Analyze an existing meal plan
    func analyzeMealPlan(_ request: AnalyzeMealPlanRequest) async throws -> MealPlanAnalysis {
        return try await networkManager.post(
            "/ai/analyze-meal-plan/",
            body: request,
            responseType: MealPlanAnalysis.self,
            requiresAuth: true
        )
    }

    // MARK: - Convenience Methods

    /// Generate a simple meal plan with basic preferences
    func generateSimpleMealPlan(
        description: String,
        dietType: DietType? = nil,
        allergies: [String] = [],
        calorieTarget: Int? = nil
    ) async throws -> MealPlan {

        var dietaryPreferences: [String: String] = [:]
        if let dietType = dietType {
            dietaryPreferences["dietType"] = dietType.rawValue
        }

        let request = GenerateMealPlanRequest(
            planDescription: description,
            dietaryPreferences: dietaryPreferences.isEmpty ? nil : dietaryPreferences,
            allergies: allergies.isEmpty ? nil : allergies,
            dislikes: nil,
            calorieTarget: calorieTarget,
            additionalRequirements: nil
        )

        return try await generateMealPlan(request)
    }

    /// Quick meal plan analysis
    func quickAnalyzeMealPlan(mealPlanId: String) async throws -> MealPlanAnalysis {
        let request = AnalyzeMealPlanRequest(
            mealPlanId: mealPlanId,
            planDescription: nil,
            analysisType: .full,
            includeRecommendations: true
        )

        return try await analyzeMealPlan(request)
    }
}

// MARK: - Generate Recipe Details Request
struct GenerateRecipeDetailsRequest: Codable {
    let name: String
}