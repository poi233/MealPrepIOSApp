//
//  MealPlanTemplateService.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/23/25.
//

import Foundation

// MARK: - Meal Plan Template Service
class MealPlanTemplateService {
    private let networkManager = NetworkManager.shared
    
    // MARK: - Template Operations (Using existing meal plan endpoints)
    
    /// Save current meal plan as template (creates a new meal plan with template naming)
    func createTemplate(_ request: CreateMealPlanTemplateRequest) async throws -> MealPlanTemplateResponse {
        // Convert template request to meal plan creation request
        let mealPlanRequest = CreateMealPlanRequest(
            name: "Template: \(request.name)",
            description: request.description ?? "Saved as template",
            startDate: Date(), // Use current date as placeholder for templates
            endDate: Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date(),
            items: request.meals.map { templateMeal in
                CreateMealPlanItemRequest(
                    recipeId: templateMeal.recipeId,
                    dayOfWeek: templateMeal.dayOfWeek,
                    mealType: templateMeal.mealType,
                    servingSize: templateMeal.servingSize
                )
            },
            preferences: nil
        )
        
        // Create meal plan using standard endpoint
        let createdMealPlan = try await networkManager.post(
            "/meal-plans/",
            body: mealPlanRequest,
            responseType: MealPlan.self,
            requiresAuth: true
        )
        
        // Convert back to template response format
        return MealPlanTemplateResponse(
            id: createdMealPlan.id,
            name: request.name, // Use original name without "Template:" prefix
            description: request.description,
            meals: request.meals.map { templateMeal in
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
        let response = try await networkManager.get(
            "/meal-plans/",
            responseType: PaginatedResponse<MealPlan>.self,
            requiresAuth: true
        )
        
        // Filter for templates (meal plans with "Template:" prefix)
        let templateMealPlans = response.results.filter { mealPlan in
            mealPlan.name.hasPrefix("Template:")
        }
        
        // Convert to MealPlanTemplate array
        return templateMealPlans.map { mealPlan in
            let cleanName = String(mealPlan.name.dropFirst(10)) // Remove "Template: " prefix
            return MealPlanTemplate(
                id: mealPlan.id,
                name: cleanName,
                description: mealPlan.description,
                category: .healthy, // Default category
                previewMeals: extractPreviewMeals(from: mealPlan.items ?? [])
            )
        }
    }
    
    /// Get a specific template with full details
    func getTemplate(id: String) async throws -> MealPlanTemplateDetail {
        let mealPlan = try await networkManager.get(
            "/meal-plans/\(id)/",
            responseType: MealPlan.self,
            requiresAuth: true
        )
        
        let cleanName = mealPlan.name.hasPrefix("Template:") ? 
            String(mealPlan.name.dropFirst(10)) : mealPlan.name
        
        let templateMeals = (mealPlan.items ?? []).map { item in
            MealPlanTemplateMeal(
                id: String(item.id ?? 0),
                recipeId: item.recipe?.id ?? "",
                recipe: item.recipe,
                dayOfWeek: item.dayOfWeek,
                mealType: item.mealType,
                servingSize: 1.0 // Default serving size
            )
        }
        
        return MealPlanTemplateDetail(
            id: mealPlan.id,
            name: cleanName,
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
            name: updates.name.map { "Template: \($0)" }, // Add template prefix
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
        try await networkManager.delete("/meal-plans/\(id)/", requiresAuth: true)
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
            name: "Week of \(DateFormatter.shortDate.string(from: weekStartDate))",
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
}

// MARK: - Template Models

struct MealPlanTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let category: TemplateCategory
    let previewMeals: [String]?
    
    enum TemplateCategory: String, Codable, CaseIterable {
        case healthy = "healthy"
        case quick = "quick"
        case family = "family"
        case vegetarian = "vegetarian"
        case budget = "budget"
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