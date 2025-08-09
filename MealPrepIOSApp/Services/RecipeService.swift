//
//  RecipeService.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/20/25.
//

import Foundation

// MARK: - Recipe Service
class RecipeService {
    private let networkManager = NetworkManager.shared

    // MARK: - Recipe CRUD Operations

    /// Get paginated list of recipes with optional filters
    func getRecipes(page: Int = 1, pageSize: Int = 20, filters: RecipeFilters? = nil) async throws -> PaginatedResponse<Recipe> {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]

        // Add filter parameters
        if let filters = filters {
            if let search = filters.search, !search.isEmpty {
                queryItems.append(URLQueryItem(name: "search", value: search))
            }
            if let cuisine = filters.cuisine {
                queryItems.append(URLQueryItem(name: "cuisine", value: cuisine))
            }
            if let difficulty = filters.difficulty {
                queryItems.append(URLQueryItem(name: "difficulty", value: difficulty.rawValue))
            }
            if let prepTimeMax = filters.prepTimeMax {
                queryItems.append(URLQueryItem(name: "prep_time__lte", value: String(prepTimeMax)))
            }
            if let cookTimeMax = filters.cookTimeMax {
                queryItems.append(URLQueryItem(name: "cook_time__lte", value: String(cookTimeMax)))
            }
            if let totalTimeMax = filters.totalTimeMax {
                queryItems.append(URLQueryItem(name: "total_time__lte", value: String(totalTimeMax)))
            }
            if let avgRatingMin = filters.avgRatingMin {
                queryItems.append(URLQueryItem(name: "avg_rating__gte", value: String(avgRatingMin)))
            }
            if let tags = filters.tags, !tags.isEmpty {
                for tag in tags {
                    queryItems.append(URLQueryItem(name: "tags", value: tag))
                }
            }
            if let mealType = filters.mealType {
                queryItems.append(URLQueryItem(name: "meal_type", value: mealType.rawValue))
            }
            if let myRecipes = filters.myRecipes, myRecipes {
                queryItems.append(URLQueryItem(name: "my_recipes", value: "true"))
            }
        }

        return try await networkManager.get(
            "/recipes/",
            queryItems: queryItems,
            responseType: PaginatedResponse<Recipe>.self,
            requiresAuth: true
        )
    }

    /// Get a specific recipe by ID
    func getRecipe(id: String) async throws -> Recipe {
        return try await networkManager.get(
            "/recipes/\(id)/",
            responseType: Recipe.self,
            requiresAuth: true
        )
    }

    /// Create a new recipe
    func createRecipe(_ recipe: CreateRecipeRequest) async throws -> Recipe {
        print("[DEBUG] RecipeService.createRecipe - About to send request with imageUrl: '\(recipe.imageUrl ?? "nil")'")

        let result = try await networkManager.post(
            "/recipes/",
            body: recipe,
            responseType: Recipe.self,
            requiresAuth: true
        )

        print("[DEBUG] RecipeService.createRecipe - Received response:")
        print("[DEBUG] RecipeService.createRecipe - Response recipe ID: \(result.id)")
        print("[DEBUG] RecipeService.createRecipe - Response recipe name: \(result.name)")
        print("[DEBUG] RecipeService.createRecipe - Response recipe imageUrl: '\(result.imageUrl ?? "nil")'")

        return result
    }

    /// Update an existing recipe (full update)
    func updateRecipe(id: String, recipe: CreateRecipeRequest) async throws -> Recipe {
        return try await networkManager.put(
            "/recipes/\(id)/",
            body: recipe,
            responseType: Recipe.self,
            requiresAuth: true
        )
    }

    /// Partially update an existing recipe
    func patchRecipe(id: String, updates: UpdateRecipeRequest) async throws -> Recipe {
        return try await networkManager.patch(
            "/recipes/\(id)/",
            body: updates,
            responseType: Recipe.self,
            requiresAuth: true
        )
    }

    /// Delete a recipe
    func deleteRecipe(id: String) async throws {
        try await networkManager.delete("/recipes/\(id)/", requiresAuth: true)
    }

    // MARK: - Search and Discovery

    /// Search recipes with advanced query
    func searchRecipes(query: String, filters: RecipeFilters? = nil, page: Int = 1, pageSize: Int = 20) async throws -> PaginatedResponse<Recipe> {
        var searchFilters = filters ?? RecipeFilters()
        searchFilters = RecipeFilters(
            search: query,
            cuisine: searchFilters.cuisine,
            difficulty: searchFilters.difficulty,
            prepTimeMax: searchFilters.prepTimeMax,
            cookTimeMax: searchFilters.cookTimeMax,
            totalTimeMax: searchFilters.totalTimeMax,
            avgRatingMin: searchFilters.avgRatingMin,
            tags: searchFilters.tags,
            mealType: searchFilters.mealType,
            myRecipes: searchFilters.myRecipes
        )

        return try await getRecipes(page: page, pageSize: pageSize, filters: searchFilters)
    }

    /// Get user's own recipes
    func getMyRecipes(page: Int = 1, pageSize: Int = 20) async throws -> PaginatedResponse<Recipe> {
        return try await networkManager.get(
            "/recipes/my_recipes/",
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "page_size", value: String(pageSize))
            ],
            responseType: PaginatedResponse<Recipe>.self,
            requiresAuth: true
        )
    }

    // MARK: - Convenience Methods

    /// Get recipes by cuisine
    func getRecipesByCuisine(_ cuisine: String, page: Int = 1) async throws -> PaginatedResponse<Recipe> {
        let filters = RecipeFilters(cuisine: cuisine)
        return try await getRecipes(page: page, filters: filters)
    }

    /// Get recipes by difficulty
    func getRecipesByDifficulty(_ difficulty: Difficulty, page: Int = 1) async throws -> PaginatedResponse<Recipe> {
        let filters = RecipeFilters(difficulty: difficulty)
        return try await getRecipes(page: page, filters: filters)
    }

    /// Get quick recipes (under 30 minutes total time)
    func getQuickRecipes(page: Int = 1) async throws -> PaginatedResponse<Recipe> {
        let filters = RecipeFilters(totalTimeMax: 30)
        return try await getRecipes(page: page, filters: filters)
    }

    /// Get highly rated recipes (4+ stars)
    func getHighlyRatedRecipes(page: Int = 1) async throws -> PaginatedResponse<Recipe> {
        let filters = RecipeFilters(avgRatingMin: 4.0)
        return try await getRecipes(page: page, filters: filters)
    }

    /// Get recipes by tags
    func getRecipesByTags(_ tags: [String], page: Int = 1) async throws -> PaginatedResponse<Recipe> {
        let filters = RecipeFilters(tags: tags)
        return try await getRecipes(page: page, filters: filters)
    }

    // MARK: - AI Recipe Generation

    /// Generate recipe details using AI
    func generateRecipeWithAI(_ request: AIRecipeGenerationRequest) async throws -> AIGeneratedRecipe {
        print("[DEBUG] RecipeService.generateRecipeWithAI - About to request recipe generation for: '\(request.name)'")

        let result = try await networkManager.post(
            "/ai/generate-recipe-details/",
            body: request,
            responseType: AIGeneratedRecipe.self,
            requiresAuth: true
        )

        print("[DEBUG] RecipeService.generateRecipeWithAI - Received AIGeneratedRecipe:")
        print("[DEBUG] RecipeService.generateRecipeWithAI - Recipe name: '\(result.name)'")
        print("[DEBUG] RecipeService.generateRecipeWithAI - Recipe imageUrl: '\(result.imageUrl ?? "nil")'")

        return result
    }

    /// Create recipe from AI-generated data
    func createRecipeFromAI(_ request: CreateRecipeFromAIRequest) async throws -> Recipe {
        print("[DEBUG] RecipeService.createRecipeFromAI - About to send AI request")
        print("[DEBUG] RecipeService.createRecipeFromAI - AI recipe data name: '\(request.aiRecipeData.name)'")
        print("[DEBUG] RecipeService.createRecipeFromAI - AI recipe data imageUrl: '\(request.aiRecipeData.imageUrl ?? "nil")'")

        // The backend returns a nested response format: {"success": true, "recipe": {...}, "status": "created"}
        let response = try await networkManager.post(
            "/ai/create-recipe-from-ai/",
            body: request,
            responseType: CreateRecipeFromAIResponse.self,
            requiresAuth: true
        )

        print("[DEBUG] RecipeService.createRecipeFromAI - Received nested AI response:")
        print("[DEBUG] RecipeService.createRecipeFromAI - Success: \(response.success)")
        print("[DEBUG] RecipeService.createRecipeFromAI - Status: \(response.status)")
        print("[DEBUG] RecipeService.createRecipeFromAI - Recipe ID: \(response.recipe.id)")
        print("[DEBUG] RecipeService.createRecipeFromAI - Recipe name: \(response.recipe.name)")
        print("[DEBUG] RecipeService.createRecipeFromAI - Recipe imageUrl: '\(response.recipe.imageUrl ?? "nil")'")

        // Return the extracted recipe from the nested response
        return response.recipe
    }

    /// Apply a RecipeStub to user's meal plan by converting it to a complete Recipe
    func applyMealToPlan(_ request: ApplyMealRequest) async throws -> ApplyMealResponse {
        print("[DEBUG] RecipeService.applyMealToPlan - About to send apply meal request")
        print("[DEBUG] RecipeService.applyMealToPlan - Recipe stub name: '\(request.recipeStub.name)'")
        print("[DEBUG] RecipeService.applyMealToPlan - Day of week: \(request.dayOfWeek)")
        print("[DEBUG] RecipeService.applyMealToPlan - Meal type: \(request.mealType)")

        let response = try await networkManager.post(
            "/ai/apply-meal-to-plan/",
            body: request,
            responseType: ApplyMealResponse.self,
            requiresAuth: true
        )

        print("[DEBUG] RecipeService.applyMealToPlan - Received apply meal response:")
        print("[DEBUG] RecipeService.applyMealToPlan - Success: \(response.success)")
        print("[DEBUG] RecipeService.applyMealToPlan - Message: \(response.message ?? "nil")")
        if let recipe = response.recipe {
            print("[DEBUG] RecipeService.applyMealToPlan - Created recipe: \(recipe.name)")
        }

        return response
    }
}
