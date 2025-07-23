//
//  MealPlanTemplateService.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/22/25.
//

import Foundation

// MARK: - Meal Plan Template Service
class MealPlanTemplateService {
    private let networkManager = NetworkManager.shared
    
    // MARK: - Template CRUD Operations
    
    /// Create a new meal plan template
    func createTemplate(_ request: CreateMealPlanTemplateRequest) async throws -> MealPlanTemplateResponse {
        return try await networkManager.post(
            "/meal-plan-templates/",
            body: request,
            responseType: MealPlanTemplateResponse.self,
            requiresAuth: true
        )
    }
    
    /// Get user's meal plan templates
    func getTemplates() async throws -> [MealPlanTemplate] {
        let response = try await networkManager.get(
            "/meal-plan-templates/",
            responseType: PaginatedResponse<MealPlanTemplateResponse>.self,
            requiresAuth: true
        )
        
        // Convert response to MealPlanTemplate array
        return response.results.map { templateResponse in
            MealPlanTemplate(
                id: templateResponse.id,
                name: templateResponse.name,
                description: templateResponse.description,
                category: .healthy, // Default category
                previewMeals: extractPreviewMeals(from: templateResponse.meals)
            )
        }
    }
    
    /// Get a specific template with full details
    func getTemplate(id: String) async throws -> MealPlanTemplateDetail {
        let response = try await networkManager.get(
            "/meal-plan-templates/\(id)/",
            responseType: MealPlanTemplateResponse.self,
            requiresAuth: true
        )
        
        return MealPlanTemplateDetail(
            id: response.id,
            name: response.name,
            description: response.description,
            meals: response.meals
        )
    }
    
    private func extractPreviewMeals(from meals: [MealPlanTemplateMeal]) -> [String] {
        return Array(Set(meals.compactMap { $0.recipe?.name })).prefix(3).map { String($0) }
    }
    
    
    /// Update an existing template
    func updateTemplate(id: String, updates: UpdateMealPlanTemplateRequest) async throws -> MealPlanTemplateResponse {
        return try await networkManager.patch(
            "/meal-plan-templates/\(id)/",
            body: updates,
            responseType: MealPlanTemplateResponse.self,
            requiresAuth: true
        )
    }
    
    /// Delete a template
    func deleteTemplate(id: String) async throws {
        try await networkManager.delete("/meal-plan-templates/\(id)/", requiresAuth: true)
    }
    
    /// Apply a template to create a meal plan
    func applyTemplate(templateId: String, weekStartDate: Date) async throws -> MealPlan {
        let request = ApplyTemplateRequest(
            templateId: templateId,
            weekStartDate: weekStartDate
        )
        
        return try await networkManager.post(
            "/meal-plan-templates/\(templateId)/apply/",
            body: request,
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