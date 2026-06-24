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
        let response = try await networkManager.post(
            "/ai/generate-meal-plan/",
            body: request,
            responseType: AIMealPlanResponse.self,
            requiresAuth: true
        )

        return response.mealPlan
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

// MARK: - AI Meal Plan Response
struct AIMealPlanResponse: Codable {
    let mealPlan: MealPlan

    private enum CodingKeys: String, CodingKey {
        case mealPlan = "meal_plan"
        case mealPlanCamel = "mealPlan"
        case plan
        case data
        case result
        case id
        case name
        case description
        case planDescription = "plan_description"
        case items
        case dailyMeals = "daily_meals"
        case lightweightDailyMeals = "lightweight_daily_meals"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let mealPlan = try container.decodeIfPresent(MealPlan.self, forKey: .mealPlan) {
            self.mealPlan = mealPlan
            return
        }

        if let mealPlan = try container.decodeIfPresent(MealPlan.self, forKey: .mealPlanCamel) {
            self.mealPlan = mealPlan
            return
        }

        if let mealPlan = try container.decodeIfPresent(MealPlan.self, forKey: .plan) {
            self.mealPlan = mealPlan
            return
        }

        if let nestedResponse = try container.decodeIfPresent(AIMealPlanResponse.self, forKey: .data) {
            self.mealPlan = nestedResponse.mealPlan
            return
        }

        if let nestedResponse = try container.decodeIfPresent(AIMealPlanResponse.self, forKey: .result) {
            self.mealPlan = nestedResponse.mealPlan
            return
        }

        let hasRawMealPlanFields = container.contains(.id)
            || container.contains(.name)
            || container.contains(.description)
            || container.contains(.planDescription)
            || container.contains(.items)
            || container.contains(.dailyMeals)
            || container.contains(.lightweightDailyMeals)

        guard hasRawMealPlanFields else {
            throw DecodingError.dataCorruptedError(
                forKey: .mealPlan,
                in: container,
                debugDescription: "AI meal plan response did not include meal_plan, mealPlan, plan, data, result, or raw meal plan fields"
            )
        }

        mealPlan = try MealPlan(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mealPlan, forKey: .mealPlan)
    }
}

// MARK: - Generate Recipe Details Request
struct GenerateRecipeDetailsRequest: Codable {
    let name: String
    let description: String?
    let cuisine: String?
    let difficulty: String?
    let prepTime: Int?
    let cookTime: Int?
    let mealType: String?
    let dietaryRestrictions: [String]?
    let ingredients: [String]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case cuisine
        case difficulty
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case mealType = "meal_type"
        case dietaryRestrictions = "dietary_restrictions"
        case ingredients
    }
    
    init(name: String, description: String? = nil, cuisine: String? = nil, 
         difficulty: String? = nil, prepTime: Int? = nil, cookTime: Int? = nil,
         mealType: String? = nil, dietaryRestrictions: [String]? = nil, 
         ingredients: [String]? = nil) {
        self.name = name
        self.description = description
        self.cuisine = cuisine
        self.difficulty = difficulty
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.mealType = mealType
        self.dietaryRestrictions = dietaryRestrictions
        self.ingredients = ingredients
    }
}