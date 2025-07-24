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
    
    /// Save current meal plan as template (creates a new meal plan)
    func createTemplate(_ request: CreateMealPlanTemplateRequest) async throws -> MealPlanTemplateResponse {
        print("💾 [MealPlanTemplateService] Creating template (saving as regular meal plan)")
        print("   Template name: '\(request.name)'")
        print("   Total meals: \(request.meals.count)")
        
        // Get the next Monday as week_start_date (backend requires Monday and YYYY-MM-DD format)
        let nextMonday = getNextMonday()
        print("   📅 Using week start date: \(formatDateForBackend(nextMonday)) (next Monday)")
        
        // Convert template request to meal plan creation request with correct backend format
        let mealPlanRequest = BackendCreateMealPlanRequest(
            name: request.name, // Use original name (no "Template:" prefix)
            description: request.description ?? "Saved as template",
            weekStartDate: formatDateForBackend(nextMonday), // Backend expects YYYY-MM-DD string
            items: request.meals.map { templateMeal in
                BackendCreateMealPlanItemRequest(
                    recipeId: templateMeal.recipeId,
                    dayOfWeek: templateMeal.dayOfWeek,
                    mealType: templateMeal.mealType
                    // Note: removed serving_size (not implemented in backend)
                    // Note: meal_plan field will be auto-populated by backend
                )
            }
            // Note: removed end_date (not used by backend)
            // Note: removed preferences (not needed for templates)
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
            print("      Week Start Date: \(mealPlan.weekStartDate.description)")
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
                previewMeals: extractPreviewMeals(from: mealPlan.items ?? [])
            )
            
            print("   ✅ Converted: '\(mealPlan.name)' → Template ID: \(template.id)")
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
        
        let templateName = mealPlan.name // Use original name (no prefix removal)
        
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
    
    // MARK: - Helper Methods
    
    /// Get the next Monday date (backend requires week_start_date to be Monday)
    private func getNextMonday() -> Date {
        let calendar = Calendar.current
        let today = Date()
        
        // If today is Monday, use today. Otherwise find next Monday
        let weekday = calendar.component(.weekday, from: today)
        if weekday == 1 { // Sunday = 1, so Monday = 2
            // Today is Sunday, next Monday is tomorrow
            return calendar.date(byAdding: .day, value: 1, to: today) ?? today
        } else if weekday == 2 {
            // Today is Monday, use today
            return today
        } else {
            // Find next Monday
            let daysUntilMonday = (9 - weekday) % 7
            return calendar.date(byAdding: .day, value: daysUntilMonday, to: today) ?? today
        }
    }
    
    /// Format date as YYYY-MM-DD string for backend API
    private func formatDateForBackend(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}

// MARK: - Backend-Specific Request Models (for correct API format)

/// Backend meal plan creation request with correct field types and names
struct BackendCreateMealPlanRequest: Codable {
    let name: String
    let description: String?
    let weekStartDate: String // Backend expects YYYY-MM-DD string, not Date
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
    // Note: meal_plan field is auto-populated by backend
    // Note: serving_size not implemented in backend yet
    
    enum CodingKeys: String, CodingKey {
        case recipeId = "recipe_id"
        case dayOfWeek = "day_of_week"
        case mealType = "meal_type"
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