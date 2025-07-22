//
//  MealPlanService.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import Foundation

// MARK: - Meal Plan Service
class MealPlanService {
    private let networkManager = NetworkManager.shared
    private let aiService = AIService()
    
    // MARK: - Meal Plan CRUD Operations
    
    /// Get user's meal plans
    func getMealPlans(page: Int = 1, pageSize: Int = 20) async throws -> PaginatedResponse<MealPlan> {
        let queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]
        
        return try await networkManager.get(
            "/meal-plans/",
            queryItems: queryItems,
            responseType: PaginatedResponse<MealPlan>.self,
            requiresAuth: true
        )
    }
    
    /// Get a specific meal plan by ID
    func getMealPlan(id: String) async throws -> MealPlan {
        return try await networkManager.get(
            "/meal-plans/\(id)/",
            responseType: MealPlan.self,
            requiresAuth: true
        )
    }
    
    /// Create a new meal plan
    func createMealPlan(_ request: CreateMealPlanRequest) async throws -> MealPlan {
        return try await networkManager.post(
            "/meal-plans/",
            body: request,
            responseType: MealPlan.self,
            requiresAuth: true
        )
    }
    
    /// Update an existing meal plan
    func updateMealPlan(id: String, updates: UpdateMealPlanRequest) async throws -> MealPlan {
        return try await networkManager.patch(
            "/meal-plans/\(id)/",
            body: updates,
            responseType: MealPlan.self,
            requiresAuth: true
        )
    }
    
    /// Delete a meal plan
    func deleteMealPlan(id: String) async throws {
        try await networkManager.delete("/meal-plans/\(id)/", requiresAuth: true)
    }
    
    // MARK: - Meal Plan Item Management
    
    /// Add a meal plan item
    func addMealPlanItem(
        mealPlanId: String,
        recipeId: String,
        dayOfWeek: Int,
        mealType: MealType,
        servingSize: Double = 1.0
    ) async throws -> MealPlanItem {
        let request = AddMealPlanItemRequest(
            recipeId: recipeId,
            dayOfWeek: dayOfWeek,
            mealType: mealType,
            servingSize: servingSize
        )
        
        return try await networkManager.post(
            "/meal-plans/\(mealPlanId)/items/",
            body: request,
            responseType: MealPlanItem.self,
            requiresAuth: true
        )
    }
    
    /// Remove a meal plan item
    func removeMealPlanItem(
        mealPlanId: String,
        dayOfWeek: Int,
        mealType: MealType
    ) async throws {
        try await networkManager.delete(
            "/meal-plans/\(mealPlanId)/items/\(dayOfWeek)/\(mealType.rawValue)/",
            requiresAuth: true
        )
    }
    
    /// Update a meal plan item
    func updateMealPlanItem(
        mealPlanId: String,
        itemId: String,
        servingSize: Double? = nil
    ) async throws -> MealPlanItem {
        let request = UpdateMealPlanItemRequest(servingSize: servingSize)
        
        return try await networkManager.patch(
            "/meal-plans/\(mealPlanId)/items/\(itemId)/",
            body: request,
            responseType: MealPlanItem.self,
            requiresAuth: true
        )
    }
    
    /// Get active meal plan
    func getActiveMealPlan() async throws -> MealPlan? {
        do {
            return try await networkManager.get(
                "/meal-plans/active/",
                responseType: MealPlan.self,
                requiresAuth: true
            )
        } catch {
            // Return nil if no active meal plan found
            return nil
        }
    }
    
    /// Activate a meal plan
    func activateMealPlan(id: String) async throws -> MealPlan {
        return try await networkManager.post(
            "/meal-plans/\(id)/activate/",
            body: EmptyActivateRequest(),
            responseType: MealPlan.self,
            requiresAuth: true
        )
    }
    
    /// Deactivate a meal plan
    func deactivateMealPlan(id: String) async throws -> MealPlan {
        return try await networkManager.post(
            "/meal-plans/\(id)/deactivate/",
            body: EmptyActivateRequest(),
            responseType: MealPlan.self,
            requiresAuth: true
        )
    }
    
    // MARK: - AI-Powered Meal Plan Generation
    
    /// Generate a meal plan using AI
    func generateMealPlan(preferences: MealPlanPreferences, description: String) async throws -> MealPlan {
        var dietaryPrefs: [String: String] = [:]
        
        if let restrictions = preferences.dietaryRestrictions, !restrictions.isEmpty {
            dietaryPrefs["dietType"] = restrictions.first // Simplified for now
        }
        
        let request = GenerateMealPlanRequest(
            planDescription: description,
            dietaryPreferences: dietaryPrefs.isEmpty ? nil : dietaryPrefs,
            allergies: preferences.excludeIngredients,
            dislikes: nil,
            calorieTarget: preferences.targetCalories,
            weekStartDate: Date(),
            additionalRequirements: nil
        )
        
        return try await aiService.generateMealPlan(request)
    }
    
    /// Generate a meal plan with custom parameters
    func generateCustomMealPlan(
        description: String,
        dietType: DietType? = nil,
        allergies: [String] = [],
        dislikes: [String] = [],
        calorieTarget: Int? = nil,
        weekStartDate: Date? = nil,
        additionalRequirements: String? = nil
    ) async throws -> MealPlan {
        
        var dietaryPreferences: [String: String] = [:]
        if let dietType = dietType {
            dietaryPreferences["dietType"] = dietType.rawValue
        }
        
        let request = GenerateMealPlanRequest(
            planDescription: description,
            dietaryPreferences: dietaryPreferences.isEmpty ? nil : dietaryPreferences,
            allergies: allergies.isEmpty ? nil : allergies,
            dislikes: dislikes.isEmpty ? nil : dislikes,
            calorieTarget: calorieTarget,
            weekStartDate: weekStartDate,
            additionalRequirements: additionalRequirements
        )
        
        return try await aiService.generateMealPlan(request)
    }
    
    // MARK: - Meal Plan Analysis
    
    /// Analyze a meal plan using AI
    func analyzeMealPlan(id: String, analysisType: AnalysisType = .full) async throws -> MealPlanAnalysis {
        let request = AnalyzeMealPlanRequest(
            mealPlanId: id,
            planDescription: nil,
            analysisType: analysisType,
            includeRecommendations: true
        )
        
        return try await aiService.analyzeMealPlan(request)
    }
    
    // MARK: - Shopping List Generation
    
    /// Generate shopping list from meal plan
    func generateShoppingList(mealPlan: MealPlan) async throws -> [ShoppingListItem] {
        var ingredientMap: [String: ShoppingListItem] = [:]
        
        // Process all meal plan items
        guard let items = mealPlan.items else {
            return []
        }
        
        for item in items {
            guard let recipe = item.recipe else { continue }
            
            for ingredient in recipe.ingredients {
                let ingredientName = ingredient.name
                let amount = ingredient.amount
                let unit = ingredient.unit
                
                if let existingItem = ingredientMap[ingredientName] {
                    // Combine with existing item
                    var recipes = existingItem.recipes
                    if !recipes.contains(recipe.name) {
                        recipes.append(recipe.name)
                    }
                    
                    ingredientMap[ingredientName] = ShoppingListItem(
                        ingredient: ingredientName,
                        amount: combineAmounts(existingItem.amount, amount),
                        unit: unit,
                        recipes: recipes
                    )
                } else {
                    // Create new item
                    ingredientMap[ingredientName] = ShoppingListItem(
                        ingredient: ingredientName,
                        amount: amount,
                        unit: unit,
                        recipes: [recipe.name]
                    )
                }
            }
        }
        
        return Array(ingredientMap.values).sorted { $0.ingredient < $1.ingredient }
    }
    
    // MARK: - Meal Plan Templates
    
    /// Get available meal plan templates
    func getMealPlanTemplates() async -> [MealPlanTemplate] {
        // For now, return static templates
        // In the future, these could come from the backend
        return MealPlanTemplate.allTemplates
    }
    
    /// Apply a template to create a meal plan
    func createMealPlanFromTemplate(_ template: MealPlanTemplate, preferences: MealPlanPreferences) async throws -> MealPlan {
        let description = "\(template.description). Preferences: \(template.tags.joined(separator: ", "))"
        return try await generateMealPlan(preferences: preferences, description: description)
    }
    
    // MARK: - Convenience Methods
    
    /// Get all user's meal plans (without pagination)
    func getAllMealPlans() async throws -> [MealPlan] {
        var allMealPlans: [MealPlan] = []
        var currentPage = 1
        var hasMore = true
        
        while hasMore {
            let response = try await getMealPlans(page: currentPage, pageSize: 50)
            allMealPlans.append(contentsOf: response.results)
            
            hasMore = response.next != nil
            currentPage += 1
        }
        
        return allMealPlans
    }
    
    /// Get current week's meal plan
    func getCurrentWeekMealPlan() async throws -> MealPlan? {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        // Search for meal plans that start this week
        let allMealPlans = try await getAllMealPlans()
        
        return allMealPlans.first { mealPlan in
            calendar.isDate(mealPlan.weekStartDate, inSameDayAs: weekStart)
        }
    }
    
    /// Duplicate a meal plan for a new week
    func duplicateMealPlan(id: String, newWeekStartDate: Date) async throws -> MealPlan {
        let originalPlan = try await getMealPlan(id: id)
        
        let request = CreateMealPlanRequest(
            name: "\(originalPlan.name) (Copy)",
            description: originalPlan.description,
            startDate: newWeekStartDate,
            endDate: Calendar.current.date(byAdding: .day, value: 6, to: newWeekStartDate) ?? newWeekStartDate,
            preferences: MealPlanPreferences(
                targetCalories: nil,
                dietaryRestrictions: nil,
                excludeIngredients: nil,
                cuisinePreferences: nil,
                mealTypes: MealType.allCases,
                maxPrepTime: nil,
                budgetLevel: nil
            )
        )
        
        return try await createMealPlan(request)
    }
    
    // MARK: - Private Helper Methods
    
    private func combineAmounts(_ amount1: String, _ amount2: String) -> String {
        // Simple amount combination - in a real app, this would be more sophisticated
        if let num1 = Double(amount1), let num2 = Double(amount2) {
            return String(num1 + num2)
        }
        return "\(amount1) + \(amount2)"
    }
}

// MARK: - Request Models

struct UpdateMealPlanRequest: Codable {
    let name: String?
    let description: String?
    let dailyMeals: [DailyMeal]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case dailyMeals = "daily_meals"
    }
}

struct AddMealPlanItemRequest: Codable {
    let recipeId: String
    let dayOfWeek: Int
    let mealType: MealType
    let servingSize: Double
    
    enum CodingKeys: String, CodingKey {
        case recipeId = "recipe_id"
        case dayOfWeek = "day_of_week"
        case mealType = "meal_type"
        case servingSize = "serving_size"
    }
}

struct UpdateMealPlanItemRequest: Codable {
    let servingSize: Double?
    
    enum CodingKeys: String, CodingKey {
        case servingSize = "serving_size"
    }
}

// MARK: - Empty Request for activation endpoints
private struct EmptyActivateRequest: Codable {}

// MARK: - Response Models

struct ActivateMealPlanResponse: Codable {
    let message: String
    let mealPlan: MealPlan
    
    enum CodingKeys: String, CodingKey {
        case message
        case mealPlan = "meal_plan"
    }
}

// MARK: - Meal Plan Template
struct MealPlanTemplate: Identifiable {
    let id: String
    let name: String
    let description: String
    let tags: [String]
    let mealPatterns: [MealPattern]
    
    static let allTemplates: [MealPlanTemplate] = [
        MealPlanTemplate(
            id: "balanced-week",
            name: "Balanced Week",
            description: "A well-rounded meal plan with variety in proteins, vegetables, and grains",
            tags: ["Balanced", "Nutritious", "Family-Friendly"],
            mealPatterns: []
        ),
        MealPlanTemplate(
            id: "mediterranean",
            name: "Mediterranean Style",
            description: "Fresh, healthy meals inspired by Mediterranean cuisine",
            tags: ["Mediterranean", "Heart-Healthy", "Fish", "Vegetables"],
            mealPatterns: []
        ),
        MealPlanTemplate(
            id: "quick-easy",
            name: "Quick & Easy",
            description: "Simple meals that can be prepared in 30 minutes or less",
            tags: ["Quick", "Simple", "30-min", "Busy Schedule"],
            mealPatterns: []
        ),
        MealPlanTemplate(
            id: "vegetarian",
            name: "Vegetarian Focus",
            description: "Plant-based meals with complete proteins and nutrients",
            tags: ["Vegetarian", "Plant-Based", "Protein-Rich"],
            mealPatterns: []
        ),
        MealPlanTemplate(
            id: "keto-friendly",
            name: "Keto Friendly",
            description: "Low-carb, high-fat meals perfect for ketogenic diet",
            tags: ["Keto", "Low-Carb", "High-Fat"],
            mealPatterns: []
        )
    ]
}

struct MealPattern: Codable {
    let mealType: MealType
    let recipeTypes: [String]
    let nutritionTargets: [String: Double]
}