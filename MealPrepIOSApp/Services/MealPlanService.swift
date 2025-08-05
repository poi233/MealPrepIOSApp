//
//  MealPlanService.swift
//  MealPrepIOSApp
//
//  Cleaned up and refactored by AI Assistant on 7/26/25.
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
    
    /// Remove a meal plan item by day/mealType (removes ALL items for that combination)
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
    
    /// Remove a specific meal plan item by ID (preserves other items in same day/mealType)
    func removeMealPlanItem(
        mealPlanId: String,
        itemId: String
    ) async throws {
        try await networkManager.delete(
            "/meal-plans/\(mealPlanId)/items/\(itemId)/",
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
        guard let items = mealPlan.items else { return [] }
        
        var ingredientMap: [String: ShoppingListItem] = [:]
        
        for item in items {
            guard let recipe = item.recipe else { continue }
            
            for ingredient in recipe.ingredients {
                let key = ingredient.name
                
                if let existingItem = ingredientMap[key] {
                    var recipes = existingItem.recipes
                    if !recipes.contains(recipe.name) {
                        recipes.append(recipe.name)
                    }
                    
                    ingredientMap[key] = ShoppingListItem(
                        ingredient: key,
                        amount: combineAmounts(existingItem.amount, ingredient.amount),
                        unit: ingredient.unit,
                        recipes: recipes
                    )
                } else {
                    ingredientMap[key] = ShoppingListItem(
                        ingredient: key,
                        amount: ingredient.amount,
                        unit: ingredient.unit,
                        recipes: [recipe.name]
                    )
                }
            }
        }
        
        return Array(ingredientMap.values).sorted { $0.ingredient < $1.ingredient }
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
    
    
    // REMOVED: getMealPlanForWeek method - no longer supported after weekStartDate elimination
    // Meal plans are now managed through local storage with WeeklyMealGrid
    
    /// Duplicate a meal plan for a new week
    func duplicateMealPlan(id: String, newWeekStartDate: Date) async throws -> MealPlan {
        let originalPlan = try await getMealPlan(id: id)
        let endDate = Calendar.current.date(byAdding: .day, value: 6, to: newWeekStartDate) ?? newWeekStartDate
        
        let request = CreateMealPlanRequest(
            name: "\(originalPlan.name) (Copy)",
            description: originalPlan.description,
            startDate: newWeekStartDate,
            endDate: endDate,
            items: nil,
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
    
    /// Sync weekly meal grid to backend meal plan (preserves multiple recipes per meal type)
    func syncWeeklyGridToBackend(mealPlanId: String, weeklyGrid: WeeklyMealGrid) async throws -> MealPlan {
        let currentPlan = try await getMealPlan(id: mealPlanId)
        
        // Clear existing items
        if let existingItems = currentPlan.items {
            for item in existingItems {
                if let itemId = item.id {
                    try await removeMealPlanItem(mealPlanId: mealPlanId, itemId: String(itemId))
                }
            }
        }
        
        // Add all recipes from weekly grid
        for (dayIndex, dailyMeal) in weeklyGrid.dailyMeals.enumerated() {
            try await addMealsForDay(mealPlanId: mealPlanId, dayIndex: dayIndex, meals: [
                (.breakfast, dailyMeal.breakfast),
                (.lunch, dailyMeal.lunch),
                (.dinner, dailyMeal.dinner)
            ])
        }
        
        return try await getMealPlan(id: mealPlanId)
    }
    
    // MARK: - Recent Meals and AI Recommendations
    
    /// Get recent meals used in meal plans
    func getRecentMeals(limit: Int = 10) async throws -> [Recipe] {
        // This could be implemented to fetch recently used recipes from backend
        // For now, return empty array as placeholder
        return []
    }
    
    /// Get AI-recommended recipes
    func getAIRecommendations(limit: Int = 5) async throws -> [Recipe] {
        // This could be implemented to fetch AI recommendations from backend
        // For now, return empty array as placeholder
        return []
    }
    
    // MARK: - Private Helper Methods
    
    /// Add multiple meals for a specific day
    private func addMealsForDay(mealPlanId: String, dayIndex: Int, meals: [(MealType, [Recipe])]) async throws {
        for (mealType, recipes) in meals {
            for recipe in recipes {
                _ = try await addMealPlanItem(
                    mealPlanId: mealPlanId,
                    recipeId: recipe.id,
                    dayOfWeek: dayIndex,
                    mealType: mealType,
                    servingSize: 1.0
                )
            }
        }
    }
    
    /// Combine ingredient amounts with improved logic
    private func combineAmounts(_ amount1: String, _ amount2: String) -> String {
        if let num1 = Double(amount1), let num2 = Double(amount2) {
            let combined = num1 + num2
            return combined.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(combined)) : String(combined)
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

