//
//  MealPlanTemplateService.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/23/25.
//

import Foundation

// MARK: - Custom Errors
enum MealPlanTemplateError: Error, LocalizedError {
    case recipeNotFound(recipeId: String)
    case recipeCreationFailed(recipeName: String, error: Error)
    
    var errorDescription: String? {
        switch self {
        case .recipeNotFound(let recipeId):
            return "Recipe with ID \(recipeId) not found in local storage or backend database"
        case .recipeCreationFailed(let recipeName, let error):
            return "Failed to create recipe '\(recipeName)' in backend: \(error.localizedDescription)"
        }
    }
}

// MARK: - Meal Plan Template Service
class MealPlanTemplateService {
    private let networkManager = NetworkManager.shared
    
    // MARK: - Template Operations (Using existing meal plan endpoints)
    
    /// Save current meal plan as template (creates a new meal plan)
    func createTemplate(_ request: CreateMealPlanTemplateRequest) async throws -> MealPlanTemplateResponse {
        print("💾 [MealPlanTemplateService] Creating template (saving as regular meal plan)")
        print("   Template name: '\(request.name)'")
        print("   Total meals: \(request.meals.count)")
        
        // Remove only true duplicates (same recipe in same meal slot)
        // Multiple different recipes in the same meal type for the same day are allowed
        var uniqueMeals: [CreateMealPlanTemplateMeal] = []
        var seenCombinations: Set<String> = []
        
        for meal in request.meals {
            let key = "\(meal.dayOfWeek)-\(meal.mealType)-\(meal.recipeId)"
            if !seenCombinations.contains(key) {
                uniqueMeals.append(meal)
                seenCombinations.insert(key)
                print("✅ [MealPlanTemplateService] Added meal: \(meal.mealType) for day \(meal.dayOfWeek), recipe: \(meal.recipeId)")
            } else {
                print("⚠️ [MealPlanTemplateService] Skipped true duplicate: \(meal.mealType) for day \(meal.dayOfWeek), recipe: \(meal.recipeId)")
            }
        }
        
        print("📊 [MealPlanTemplateService] Filtered meals: \(request.meals.count) → \(uniqueMeals.count)")
        
        // CRITICAL FIX: Ensure all recipes exist in backend before creating template
        print("🔧 [MealPlanTemplateService] Ensuring all recipes exist in backend database...")
        let validatedMeals = try await ensureRecipesExistInBackend(uniqueMeals)
        print("✅ [MealPlanTemplateService] Recipe validation completed. Valid meals: \(validatedMeals.count)")
        
        // Convert template request to meal plan creation request matching backend API spec
        // week_start_date is required by backend - use current week's Monday
        let weekStartDate = getMondayOfCurrentWeek()
        let mealPlanRequest = BackendCreateMealPlanRequest(
            name: request.name,
            description: request.description ?? "Saved as template",
            weekStartDate: weekStartDate,
            items: validatedMeals.map { templateMeal in
                BackendCreateMealPlanItemRequest(
                    recipeId: templateMeal.recipeId,
                    dayOfWeek: templateMeal.dayOfWeek,
                    mealType: templateMeal.mealType,
                    servingSize: templateMeal.servingSize
                )
            }
        )
        
        // Create meal plan using standard endpoint
        let createdMealPlan = try await networkManager.post(
            "/meal-plans/",
            body: mealPlanRequest,
            responseType: MealPlan.self,
            requiresAuth: true
        )
        
        print("✅ [MealPlanTemplateService] Template created successfully as meal plan ID: \(createdMealPlan.id)")
        
        // Convert back to template response format
        return MealPlanTemplateResponse(
            id: createdMealPlan.id,
            name: request.name, // Use original name
            description: request.description,
            meals: validatedMeals.map { templateMeal in
                MealPlanTemplateMeal(
                    id: nil,
                    recipeId: templateMeal.recipeId,
                    recipe: nil, // Will be populated when fetching templates
                    dayOfWeek: templateMeal.dayOfWeek,
                    mealType: templateMeal.mealType,
                    servingSize: templateMeal.servingSize
                )
            },
            createdAt: createdMealPlan.createdAt,
            updatedAt: createdMealPlan.updatedAt
        )
    }
    
    /// Get user's meal plan templates (filters meal plans that start with "Template:")
    func getTemplates() async throws -> [MealPlanTemplate] {
        print("🔧 [MealPlanTemplateService] getTemplates() called")
        print("🌐 [MealPlanTemplateService] Preparing API request:")
        print("   URL: GET /meal-plans/")
        print("   Auth Required: true")
        print("   Response Type: PaginatedResponse<MealPlan>")
        print("📝 [MealPlanTemplateService] Backend behavior:")
        print("   - API automatically filters by authenticated user (no userId needed)")
        print("   - Showing ALL meal plans as templates (no name filtering)")
        print("   - Users can use any existing meal plan as a template")
        
        let response = try await networkManager.get(
            "/meal-plans/",
            responseType: PaginatedResponse<MealPlan>.self,
            requiresAuth: true
        )
        
        print("✅ [MealPlanTemplateService] Raw API response received:")
        print("   Total results: \(response.results.count)")
        print("   Count: \(response.count)")
        print("   Next: \(response.next ?? "null")")
        print("   Previous: \(response.previous ?? "null")")
        
        print("📋 [MealPlanTemplateService] All meal plans from API:")
        for (index, mealPlan) in response.results.enumerated() {
            print("   \(index + 1). ID: \(mealPlan.id)")
            print("      Name: '\(mealPlan.name)'")
            print("      Description: '\(mealPlan.description ?? "null")'")
            // Week start date computation moved to WeeklyMealGrid - skipping for template service
            print("      Week Start Date: computed from daily meals (not directly available in MealPlan)")
            print("      User ID: \(mealPlan.userId ?? "null")")
            print("      Is Active: \(mealPlan.isActive)")
            print("      Items Count: \(mealPlan.items?.count ?? 0)")
        }
        
        print("🔄 [MealPlanTemplateService] Converting ALL meal plans to templates (no filtering):")
        print("   Using \(response.results.count) meal plans as templates")
        
        // Convert ALL meal plans to MealPlanTemplate array (no filtering)
        let templates = response.results.map { mealPlan in
            let template = MealPlanTemplate(
                id: mealPlan.id,
                name: mealPlan.name, // Use original name (no prefix removal)
                description: mealPlan.description,
                category: .healthy, // Default category
                previewMeals: extractPreviewMeals(from: mealPlan.items ?? []),
                createdAt: mealPlan.createdAt,
                updatedAt: mealPlan.updatedAt
            )
            
            print("   ✅ Converted: \(mealPlan.name)")
            if let previewMeals = template.previewMeals, !previewMeals.isEmpty {
                print("      Preview meals: \(previewMeals.joined(separator: ", "))")
            } else {
                print("      Preview meals: No items found")
            }
            
            return template
        }
        
        print("🎯 [MealPlanTemplateService] Returning \(templates.count) templates")
        return templates
    }
    
    /// Get a specific template with full details
    func getTemplate(id: String) async throws -> MealPlanTemplateDetail {
        print("🔍 [MealPlanTemplateService] Fetching template details for ID: \(id)")
        
        let mealPlan = try await networkManager.get(
            "/meal-plans/\(id)/",
            responseType: MealPlan.self,
            requiresAuth: true
        )
        
        print("📋 [MealPlanTemplateService] Template details retrieved:")
        print("   Name: '\(mealPlan.name)'")
        print("   Items: \(mealPlan.items?.count ?? 0)")
        
        // Debug: Print original meal plan summary
        if let items = mealPlan.items {
            print("🔍 [MealPlanTemplateService] Original MealPlan has \(items.count) items")
        }
        
        let templateName = mealPlan.name // Use original name (no prefix removal)
        
        let templateMeals = (mealPlan.items ?? []).enumerated().map { (index, item) in
            // Generate unique ID using index and item properties
            let uniqueId = "\(item.recipe?.id ?? "unknown")_\(item.dayOfWeek)_\(item.mealType)_\(index)"
            
            let templateMeal = MealPlanTemplateMeal(
                id: uniqueId,
                recipeId: item.recipe?.id ?? "",
                recipe: item.recipe,
                dayOfWeek: item.dayOfWeek,
                mealType: item.mealType,
                servingSize: 1.0 // Default serving size
            )
            
            // Debug: Print conversion
            print("🔄 [MealPlanTemplateService] Converting: \(templateMeal.recipe?.name ?? "Unknown")")
            
            return templateMeal
        }
        
        // Debug: Print final template meals
        print("📊 [MealPlanTemplateService] Final template meals:")
        let mealTypeDistribution = Dictionary(grouping: templateMeals) { $0.mealType }
        for (mealType, meals) in mealTypeDistribution {
            print("   \(mealType): \(meals.count) meals")
        }
        
        return MealPlanTemplateDetail(
            id: mealPlan.id,
            name: templateName,
            description: mealPlan.description,
            meals: templateMeals
        )
    }
    
    private func extractPreviewMeals(from items: [MealPlanItem]) -> [String] {
        return Array(Set(items.compactMap { $0.recipe?.name })).prefix(3).map { String($0) }
    }
    
    /// Update an existing template
    func updateTemplate(id: String, updates: UpdateMealPlanTemplateRequest) async throws -> MealPlanTemplateResponse {
        let updateRequest = UpdateMealPlanRequest(
            name: updates.name, // Use original name (no prefix)
            description: updates.description,
            dailyMeals: nil // Convert template meals to daily meals if needed
        )
        
        let updatedMealPlan = try await networkManager.patch(
            "/meal-plans/\(id)/",
            body: updateRequest,
            responseType: MealPlan.self,
            requiresAuth: true
        )
        
        return MealPlanTemplateResponse(
            id: updatedMealPlan.id,
            name: updates.name ?? updatedMealPlan.name,
            description: updatedMealPlan.description,
            meals: [], // Will be populated if needed
            createdAt: updatedMealPlan.createdAt,
            updatedAt: updatedMealPlan.updatedAt
        )
    }
    
    /// Delete a template
    func deleteTemplate(id: String) async throws {
        print("🗑️ [MealPlanTemplateService] Deleting template ID: \(id)")
        try await networkManager.delete("/meal-plans/\(id)/", requiresAuth: true)
        print("✅ [MealPlanTemplateService] Template deleted successfully")
    }
    
    /// Update existing meal plan with template meals (override items)
    func updateExistingMealPlan(mealPlanId: String, name: String?, description: String?, templateMeals: [CreateMealPlanTemplateMeal]) async throws -> MealPlan {
        print("🔄 [MealPlanTemplateService] Updating existing meal plan ID: \(mealPlanId)")
        print("   New name: \(name ?? "unchanged")")
        print("   New description: \(description ?? "unchanged")")
        print("   Template meals to apply: \(templateMeals.count)")
        
        // Remove only true duplicates (same recipe in same meal slot)
        // Multiple different recipes in the same meal type for the same day are allowed
        var uniqueMeals: [CreateMealPlanTemplateMeal] = []
        var seenCombinations: Set<String> = []
        
        for meal in templateMeals {
            let key = "\(meal.dayOfWeek)-\(meal.mealType)-\(meal.recipeId)"
            if !seenCombinations.contains(key) {
                uniqueMeals.append(meal)
                seenCombinations.insert(key)
                print("✅ [MealPlanTemplateService] Added meal: \(meal.mealType) for day \(meal.dayOfWeek), recipe: \(meal.recipeId)")
            } else {
                print("⚠️ [MealPlanTemplateService] Skipped true duplicate: \(meal.mealType) for day \(meal.dayOfWeek), recipe: \(meal.recipeId)")
            }
        }
        
        print("📊 [MealPlanTemplateService] Filtered meals: \(templateMeals.count) → \(uniqueMeals.count)")
        
        // CRITICAL FIX: Ensure all recipes exist in backend before updating meal plan
        print("🔧 [MealPlanTemplateService] Ensuring all recipes exist in backend database...")
        let validatedMeals = try await ensureRecipesExistInBackend(uniqueMeals)
        print("✅ [MealPlanTemplateService] Recipe validation completed. Valid meals: \(validatedMeals.count)")
        
        // Create update request with name, description, and new items (this will override existing items)
        let updateRequest = UpdateExistingMealPlanRequest(
            name: name,
            description: description,
            items: validatedMeals.map { templateMeal in
                BackendCreateMealPlanItemRequest(
                    recipeId: templateMeal.recipeId,
                    dayOfWeek: templateMeal.dayOfWeek,
                    mealType: templateMeal.mealType,
                    servingSize: templateMeal.servingSize
                )
            }
        )
        
        // Update the meal plan using PATCH endpoint
        let updatedMealPlan = try await networkManager.patch(
            "/meal-plans/\(mealPlanId)/",
            body: updateRequest,
            responseType: MealPlan.self,
            requiresAuth: true
        )
        
        print("✅ [MealPlanTemplateService] Meal plan updated successfully")
        print("   Updated name: \(updatedMealPlan.name)")
        return updatedMealPlan
    }
    
    /// Apply a template to create a meal plan (duplicate an existing meal plan for new week)
    func applyTemplate(templateId: String, weekStartDate: Date) async throws -> MealPlan {
        // First get the template meal plan
        let templateMealPlan = try await networkManager.get(
            "/meal-plans/\(templateId)/",
            responseType: MealPlan.self,
            requiresAuth: true
        )
        
        // Create new meal plan from template
        let newMealPlanRequest = CreateMealPlanRequest(
            name: "Week of \(weekStartDate.formatted(date: .abbreviated, time: .omitted))",
            description: "Created from template: \(templateMealPlan.name)",
            startDate: weekStartDate,
            endDate: Calendar.current.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate,
            items: (templateMealPlan.items ?? []).map { item in
                CreateMealPlanItemRequest(
                    recipeId: item.recipe?.id ?? "",
                    dayOfWeek: item.dayOfWeek,
                    mealType: item.mealType,
                    servingSize: 1.0
                )
            },
            preferences: nil
        )
        
        return try await networkManager.post(
            "/meal-plans/",
            body: newMealPlanRequest,
            responseType: MealPlan.self,
            requiresAuth: true
        )
    }
    
    // MARK: - Helper Methods
    
    /// Calculate the Monday of the current week
    private func getMondayOfCurrentWeek() -> String {
        let calendar = Calendar.current
        let today = Date()
        
        // Find the Monday of the current week
        // Calendar weekday: Sunday = 1, Monday = 2, ..., Saturday = 7
        let dayOfWeek = calendar.component(.weekday, from: today)
        let daysFromMonday = (dayOfWeek + 5) % 7  // Convert to days from Monday (0=Monday, 6=Sunday)
        
        guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            // Fallback to today if calculation fails
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: today)
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: monday)
    }
    
    /// Ensure all recipes referenced in meal plan exist in the backend database
    /// This is critical for template saving to work properly
    private func ensureRecipesExistInBackend(_ meals: [CreateMealPlanTemplateMeal]) async throws -> [CreateMealPlanTemplateMeal] {
        print("🔍 [MealPlanTemplateService] Checking \(meals.count) recipes against backend database...")
        
        let recipeService = RecipeService()
        let localMealPlanStorage = LocalMealPlanStorage.shared
        var validatedMeals: [CreateMealPlanTemplateMeal] = []
        
        for (index, meal) in meals.enumerated() {
            print("🔍 [MealPlanTemplateService] [\(index + 1)/\(meals.count)] Checking recipe ID: \(meal.recipeId)")
            
            do {
                // First, try to fetch the recipe from backend to see if it exists
                let _ = try await recipeService.getRecipe(id: meal.recipeId)
                print("✅ [MealPlanTemplateService] Recipe \(meal.recipeId) exists in backend")
                validatedMeals.append(meal)
                
            } catch {
                print("⚠️ [MealPlanTemplateService] Recipe \(meal.recipeId) not found in backend, attempting to create it...")
                
                // Recipe doesn't exist in backend, try to find it in local storage and create it
                if let localRecipe = localMealPlanStorage.findRecipeInLocalStorage(recipeId: meal.recipeId) {
                    print("📱 [MealPlanTemplateService] Found recipe '\(localRecipe.name)' in local storage, creating in backend...")
                    
                    do {
                        // Convert local recipe to AI format for backend creation
                        let aiIngredients = (localRecipe.ingredients ?? []).map { ingredient in
                            AIIngredient(
                                name: ingredient.name,
                                amount: "\(ingredient.amount) \(ingredient.unit)".trimmingCharacters(in: .whitespaces)
                            )
                        }
                        
                        let aiNutritionInfo = AINutritionInfo(
                            calories: extractNumericValue(from: localRecipe.nutritionInfo?.calories),
                            protein: extractNumericValue(from: localRecipe.nutritionInfo?.protein),
                            carbohydrates: extractNumericValue(from: localRecipe.nutritionInfo?.carbohydrates),
                            fat: extractNumericValue(from: localRecipe.nutritionInfo?.fat),
                            fiber: extractNumericValue(from: localRecipe.nutritionInfo?.fiber),
                            sodium: extractNumericValue(from: localRecipe.nutritionInfo?.sodium),
                            sugar: extractNumericValue(from: localRecipe.nutritionInfo?.sugar),
                            servings: localRecipe.nutritionInfo?.servings
                        )
                        
                        let aiRecipeData = AIGeneratedRecipe(
                            name: localRecipe.name,
                            description: localRecipe.description ?? "",
                            cuisine: localRecipe.cuisine ?? "Unknown",
                            difficulty: localRecipe.difficulty ?? .medium,
                            prepTime: localRecipe.prepTime ?? 30,
                            cookTime: localRecipe.cookTime ?? 30,
                            imageUrl: localRecipe.imageUrl,
                            ingredients: aiIngredients,
                            instructions: localRecipe.instructions ?? [],
                            nutritionInfo: aiNutritionInfo,
                            tags: localRecipe.tags ?? []
                        )
                        
                        let createRequest = CreateRecipeFromAIRequest(
                            aiRecipeData: aiRecipeData,
                            saveToAccount: true,
                            addToMealPlan: nil,
                            mealPlanDay: nil,
                            mealPlanType: nil
                        )
                        
                        let createdRecipe = try await recipeService.createRecipeFromAI(createRequest)
                        print("✅ [MealPlanTemplateService] Successfully created recipe '\(createdRecipe.name)' in backend with ID: \(createdRecipe.id)")
                        
                        // Use the created recipe's ID (should be same as original, but backend confirms it)
                        let updatedMeal = CreateMealPlanTemplateMeal(
                            recipeId: createdRecipe.id,
                            dayOfWeek: meal.dayOfWeek,
                            mealType: meal.mealType,
                            servingSize: meal.servingSize
                        )
                        validatedMeals.append(updatedMeal)
                        
                    } catch {
                        print("❌ [MealPlanTemplateService] Failed to create recipe '\(localRecipe.name)' in backend: \(error)")
                        throw MealPlanTemplateError.recipeCreationFailed(recipeName: localRecipe.name, error: error)
                    }
                    
                } else {
                    print("❌ [MealPlanTemplateService] Recipe \(meal.recipeId) not found in local storage either")
                    throw MealPlanTemplateError.recipeNotFound(recipeId: meal.recipeId)
                }
            }
        }
        
        print("🎯 [MealPlanTemplateService] Recipe validation completed: \(validatedMeals.count)/\(meals.count) recipes validated")
        return validatedMeals
    }
    
    /// Extract numeric value from nutrition string (e.g., "25g" -> 25, "10 grams" -> 10)
    private func extractNumericValue(from nutritionString: String?) -> Int? {
        guard let str = nutritionString, !str.isEmpty else { return nil }
        
        // Use regex to extract the first number from the string
        let pattern = #"(\d+(?:\.\d+)?)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)),
           let range = Range(match.range(at: 1), in: str) {
            let numberString = String(str[range])
            return Int(Double(numberString) ?? 0)
        }
        
        return nil
    }
    
    /// Extract string value from nutrition string, converting numeric values to proper string format
    private func extractStringValue(from nutritionString: String?) -> String? {
        guard let str = nutritionString, !str.isEmpty else { return nil }
        
        // Extract numeric value and return as string
        if let numericValue = extractNumericValue(from: str) {
            return String(numericValue)
        }
        
        return nil
    }
}

// MARK: - Backend-Specific Request Models (for correct API format)

/// Backend meal plan update request for overriding items
struct UpdateExistingMealPlanRequest: Codable {
    let name: String?
    let description: String?
    let items: [BackendCreateMealPlanItemRequest]
}

/// Backend meal plan creation request matching API specification
struct BackendCreateMealPlanRequest: Codable {
    let name: String
    let description: String?
    let weekStartDate: String
    let items: [BackendCreateMealPlanItemRequest]
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case weekStartDate = "week_start_date"
        case items
    }
}

/// Backend meal plan item creation request with correct field types and names
struct BackendCreateMealPlanItemRequest: Codable {
    let recipeId: String
    let dayOfWeek: Int
    let mealType: String
    let servingSize: Double
    // Note: meal_plan field is auto-populated by backend
    
    enum CodingKeys: String, CodingKey {
        case recipeId = "recipe_id"
        case dayOfWeek = "day_of_week"
        case mealType = "meal_type"
        case servingSize = "serving_size"
    }
}

// MARK: - Template Models

struct MealPlanTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let category: TemplateCategory
    let previewMeals: [String]?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum TemplateCategory: String, Codable, CaseIterable {
        case healthy = "healthy"
        case quick = "quick"
        case family = "family"
        case vegetarian = "vegetarian"
        case budget = "budget"
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, category, previewMeals
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct MealPlanTemplateDetail: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let meals: [MealPlanTemplateMeal]
}

// MARK: - Request Models

struct CreateMealPlanTemplateRequest: Codable {
    let name: String
    let description: String?
    let meals: [CreateMealPlanTemplateMeal]
}

struct CreateMealPlanTemplateMeal: Codable {
    let recipeId: String
    let dayOfWeek: Int
    let mealType: String
    let servingSize: Double
    
    enum CodingKeys: String, CodingKey {
        case recipeId = "recipe_id"
        case dayOfWeek = "day_of_week"
        case mealType = "meal_type"
        case servingSize = "serving_size"
    }
}

struct UpdateMealPlanTemplateRequest: Codable {
    let name: String?
    let description: String?
    let meals: [TemplateMealData]?
}

struct TemplateMealData: Codable {
    let recipeId: String
    let dayOfWeek: Int
    let mealType: String
    let servingSize: Double
    
    enum CodingKeys: String, CodingKey {
        case recipeId = "recipe_id"
        case dayOfWeek = "day_of_week"
        case mealType = "meal_type"
        case servingSize = "serving_size"
    }
}

struct ApplyTemplateRequest: Codable {
    let templateId: String
    let weekStartDate: Date
    
    enum CodingKeys: String, CodingKey {
        case templateId = "template_id"
        case weekStartDate = "week_start_date"
    }
}

// MARK: - Response Models

struct MealPlanTemplateResponse: Codable {
    let id: String
    let name: String
    let description: String?
    let meals: [MealPlanTemplateMeal]
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, meals
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct MealPlanTemplateMeal: Codable {
    let id: String?
    let recipeId: String
    let recipe: Recipe?
    let dayOfWeek: Int
    let mealType: String
    let servingSize: Double
    
    enum CodingKeys: String, CodingKey {
        case id
        case recipeId = "recipe_id"
        case recipe
        case dayOfWeek = "day_of_week"
        case mealType = "meal_type"
        case servingSize = "serving_size"
    }
}