//
//  MealPlan.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/20/25.
//

import Foundation

// MARK: - Meal Plan Model
struct MealPlan: Codable, Identifiable, Equatable {
    let id: String
    let userId: String?
    let name: String
    let description: String?
    let isActive: Bool
    let planDescription: String?
    let analysisText: String?
    let items: [MealPlanItem]?
    let itemsCount: Int?
    let dailyMeals: [DailyMeal]?            // Full recipes for applied meal plans
    let lightweightDailyMeals: [LightweightDailyMeal]?  // Recipe stubs for AI-generated suggestions
    let createdAt: Date
    let updatedAt: Date

    // Removed weekStartDate - weeklyMealGrid now handles date calculations internally

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case isActive = "is_active"
        case planDescription = "plan_description"
        case analysisText = "analysis_text"
        case items
        case itemsCount = "items_count"
        case dailyMeals = "daily_meals"
        case lightweightDailyMeals = "lightweight_daily_meals"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        // Removed weekStartDate from CodingKeys - no longer sent to/from backend
    }

    // Standard initializer - weekStartDate removed
    init(
        id: String,
        userId: String?,
        name: String,
        description: String?,
        isActive: Bool,
        planDescription: String?,
        analysisText: String?,
        items: [MealPlanItem]?,
        itemsCount: Int?,
        dailyMeals: [DailyMeal]? = nil,
        lightweightDailyMeals: [LightweightDailyMeal]? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.description = description
        self.isActive = isActive
        self.planDescription = planDescription
        self.analysisText = analysisText
        self.items = items
        self.itemsCount = itemsCount
        self.dailyMeals = dailyMeals
        self.lightweightDailyMeals = lightweightDailyMeals
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // AI preview responses are sometimes generated before a persisted database row exists.
        if let idString = try? container.decode(String.self, forKey: .id), !idString.isEmpty {
            id = idString
        } else if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = String(idInt)
        } else {
            id = "ai-generated-\(UUID().uuidString)"
        }

        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        planDescription = try container.decodeIfPresent(String.self, forKey: .planDescription)

        if let decodedName = try container.decodeIfPresent(String.self, forKey: .name), !decodedName.isEmpty {
            name = decodedName
        } else if let decodedPlanDescription = planDescription, !decodedPlanDescription.isEmpty {
            name = "AI Generated Meal Plan"
        } else {
            name = "Meal Plan"
        }

        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        analysisText = try container.decodeIfPresent(String.self, forKey: .analysisText)
        items = try container.decodeIfPresent([MealPlanItem].self, forKey: .items)
        itemsCount = try container.decodeIfPresent(Int.self, forKey: .itemsCount)
        dailyMeals = try container.decodeIfPresent([DailyMeal].self, forKey: .dailyMeals)
        lightweightDailyMeals = try container.decodeIfPresent([LightweightDailyMeal].self, forKey: .lightweightDailyMeals)

        // weekStartDate parsing completely removed - backend may still send it but iOS ignores it
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? Date()
    }

    // MARK: - Equatable Implementation
    static func == (lhs: MealPlan, rhs: MealPlan) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Meal Plan Item
struct MealPlanItem: Codable, Identifiable {
    let id: Int?
    let mealPlanId: String?
    let recipe: Recipe?
    let recipeId: String?
    let dayOfWeek: Int
    let mealType: String
    let addedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case mealPlanId = "meal_plan"
        case recipe
        case recipeId = "recipe_id"
        case dayOfWeek = "day_of_week"
        case mealType = "meal_type"
        case addedAt = "added_at"
    }

    var dayName: String {
        let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return dayOfWeek < days.count ? days[dayOfWeek] : "Unknown"
    }

    static let sampleItem = MealPlanItem(
        id: 1,
        mealPlanId: "1",
        recipe: Recipe.sampleRecipe,
        recipeId: Recipe.sampleRecipe.id,
        dayOfWeek: 0,
        mealType: "breakfast",
        addedAt: Date()
    )
}

// MARK: - Daily Meal Structure (UI Helper)
struct DailyMeal: Codable, Identifiable {
    let id = UUID()
    let day: String
    let breakfast: [Recipe]  // Changed from MealItem to Recipe
    let lunch: [Recipe]      // Changed from MealItem to Recipe
    let dinner: [Recipe]     // Changed from MealItem to Recipe

    enum CodingKeys: String, CodingKey {
        case day
        case breakfast
        case lunch
        case dinner
    }
}

// MARK: - Meal Item (UI Helper) - DEPRECATED: Now using Recipe directly in DailyMeal

// MARK: - Meal Plan Generation Request
struct GenerateMealPlanRequest: Codable {
    let planDescription: String
    let dietaryPreferences: [String: String]?
    let allergies: [String]?
    let dislikes: [String]?
    let calorieTarget: Int?
    let additionalRequirements: String?

    enum CodingKeys: String, CodingKey {
        case planDescription = "plan_description"
        case dietaryPreferences = "dietary_preferences"
        case allergies
        case dislikes
        case calorieTarget = "calorie_target"
        case additionalRequirements = "additional_requirements"
    }
}

// MARK: - Meal Plan Analysis Request
struct AnalyzeMealPlanRequest: Codable {
    let mealPlanId: String
    let planDescription: String?
    let analysisType: AnalysisType?
    let includeRecommendations: Bool?

    enum CodingKeys: String, CodingKey {
        case mealPlanId = "meal_plan_id"
        case planDescription = "plan_description"
        case analysisType = "analysis_type"
        case includeRecommendations = "include_recommendations"
    }
}

// Enums moved to SharedEnums.swift to avoid duplication

// MARK: - Meal Plan Analysis Response
struct MealPlanAnalysis: Codable {
    let mealPlanId: String
    let analysisType: AnalysisType
    let totalRecipes: Int
    let analysisText: String
    let analysisDate: Date

    enum CodingKeys: String, CodingKey {
        case mealPlanId = "meal_plan_id"
        case analysisType = "analysis_type"
        case totalRecipes = "total_recipes"
        case analysisText = "analysis_text"
        case analysisDate = "analysis_date"
    }
}

// MARK: - Weekly Meal Grid (UI Helper)
struct WeeklyMealGrid: Codable {
    var dailyMeals: [DailyMealSlots]

    init(weekStartDate: Date = Date().startOfWeek()) {
        self.dailyMeals = []

        // Initialize 7 days starting from the selected Monday-based week.
        let calendar = Calendar.mondayFirst
        let actualWeekStart = weekStartDate.startOfWeek(using: calendar)

        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: actualWeekStart) {
                // Use custom day names array starting with Monday
                let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
                let dayName = dayNames[i]
                dailyMeals.append(DailyMealSlots(day: dayName, date: date))
            }
        }
    }

    // Helper methods for date extraction from dailyMeals when needed
    func getWeekStartDate() -> Date {
        return dailyMeals.first?.date ?? Date().startOfWeek()
    }

    func getWeekEndDate() -> Date {
        return dailyMeals.last?.date ?? Date().endOfWeek()
    }

    // Custom Codable implementation to exclude weekStartDate from encoding/decoding
    enum CodingKeys: String, CodingKey {
        case dailyMeals
        // weekStartDate excluded - it's now computed from dailyMeals dates
    }
}

struct DailyMealSlots: Identifiable, Codable {
    let id: UUID
    let day: String
    let date: Date
    var breakfast: [Recipe] = []
    var lunch: [Recipe] = []
    var dinner: [Recipe] = []

    init(day: String, date: Date) {
        self.id = UUID()
        self.day = day
        self.date = date
    }

    // Custom Codable implementation to handle UUID
    enum CodingKeys: String, CodingKey {
        case id, day, date, breakfast, lunch, dinner
    }
}

// MARK: - Shopping List
struct ShoppingListItem: Codable, Identifiable {
    let id = UUID()
    let ingredient: String
    let amount: String
    let unit: String
    let category: String // Category for grouping ingredients (e.g., "Produce", "Dairy", "Meat")
    let recipes: [String] // Recipe names that use this ingredient
    var isCompleted: Bool = false

    enum CodingKeys: String, CodingKey {
        case ingredient
        case amount
        case unit
        case category
        case recipes
    }
}

// MARK: - Meal Plan Preferences
struct MealPlanPreferences: Codable {
    let targetCalories: Int?
    let dietaryRestrictions: [String]?
    let excludeIngredients: [String]?
    let cuisinePreferences: [String]?
    let mealTypes: [MealType]
    let maxPrepTime: Int?
    let budgetLevel: BudgetLevel?

    enum CodingKeys: String, CodingKey {
        case targetCalories = "target_calories"
        case dietaryRestrictions = "dietary_restrictions"
        case excludeIngredients = "exclude_ingredients"
        case cuisinePreferences = "cuisine_preferences"
        case mealTypes = "meal_types"
        case maxPrepTime = "max_prep_time"
        case budgetLevel = "budget_level"
    }
}

// BudgetLevel enum moved to SharedEnums.swift to avoid duplication

// MARK: - Create Meal Plan Request
struct CreateMealPlanRequest: Codable {
    let name: String
    let description: String?
    let startDate: Date
    let endDate: Date
    let items: [CreateMealPlanItemRequest]?
    let preferences: MealPlanPreferences?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case startDate = "week_start_date" // Changed to match backend
        case endDate = "end_date"
        case items
        case preferences
    }
}

// MARK: - Create Meal Plan Item Request
struct CreateMealPlanItemRequest: Codable {
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

// MARK: - WeeklyMealGrid Extensions

extension WeeklyMealGrid {
    /// Check if there are any meals planned for this week
    var hasAnyMeals: Bool {
        return dailyMeals.contains { day in
            !day.breakfast.isEmpty || !day.lunch.isEmpty || !day.dinner.isEmpty
        }
    }

    /// Get total count of all meals (recipes) in the week
    var totalMealsCount: Int {
        return dailyMeals.reduce(0) { total, day in
            total + day.breakfast.count + day.lunch.count + day.dinner.count
        }
    }

    /// Remove a recipe by ID from all meal slots
    mutating func removeRecipe(_ recipeId: String) {
        for dayIndex in 0..<dailyMeals.count {
            dailyMeals[dayIndex].breakfast.removeAll { $0.id == recipeId }
            dailyMeals[dayIndex].lunch.removeAll { $0.id == recipeId }
            dailyMeals[dayIndex].dinner.removeAll { $0.id == recipeId }
        }
    }
}

