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
    let weekStartDate: Date
    let isActive: Bool
    let planDescription: String?
    let analysisText: String?
    let items: [MealPlanItem]?
    let itemsCount: Int?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case weekStartDate = "week_start_date"
        case isActive = "is_active"
        case planDescription = "plan_description"
        case analysisText = "analysis_text"
        case items
        case itemsCount = "items_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle id as either String or Int
        if let idString = try? container.decode(String.self, forKey: .id) {
            id = idString
        } else if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = String(idInt)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "ID must be either String or Int")
        }
        
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        planDescription = try container.decodeIfPresent(String.self, forKey: .planDescription)
        analysisText = try container.decodeIfPresent(String.self, forKey: .analysisText)
        items = try container.decodeIfPresent([MealPlanItem].self, forKey: .items)
        itemsCount = try container.decodeIfPresent(Int.self, forKey: .itemsCount)
        
        // Handle flexible date parsing for week_start_date
        if let dateString = try? container.decode(String.self, forKey: .weekStartDate) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            // Try simple date format first (YYYY-MM-DD)
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateString) {
                weekStartDate = date
            } else {
                // Try ISO-8601 format with microseconds
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
                if let date = formatter.date(from: dateString) {
                    weekStartDate = date
                } else {
                    // Try ISO-8601 format with milliseconds
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                    if let date = formatter.date(from: dateString) {
                        weekStartDate = date
                    } else {
                        // Try basic ISO-8601 format
                        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                        if let date = formatter.date(from: dateString) {
                            weekStartDate = date
                        } else {
                            throw DecodingError.dataCorruptedError(forKey: .weekStartDate, in: container, debugDescription: "Cannot decode date string '\(dateString)'. Expected formats: yyyy-MM-dd or ISO-8601")
                        }
                    }
                }
            }
        } else {
            // Fallback to standard Date decoding
            weekStartDate = try container.decode(Date.self, forKey: .weekStartDate)
        }
        
        // Handle flexible date parsing for timestamps
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
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
    let breakfast: [MealItem]
    let lunch: [MealItem]
    let dinner: [MealItem]
    
    enum CodingKeys: String, CodingKey {
        case day
        case breakfast
        case lunch
        case dinner
    }
}

// MARK: - Meal Item (UI Helper)
struct MealItem: Codable, Identifiable {
    let id = UUID()
    let recipeName: String
    let ingredients: [String]
    let instructions: [String]
    
    enum CodingKeys: String, CodingKey {
        case recipeName
        case ingredients
        case instructions
    }
}

// MARK: - Meal Plan Generation Request
struct GenerateMealPlanRequest: Codable {
    let planDescription: String
    let dietaryPreferences: [String: String]?
    let allergies: [String]?
    let dislikes: [String]?
    let calorieTarget: Int?
    let weekStartDate: Date?
    let additionalRequirements: String?
    
    enum CodingKeys: String, CodingKey {
        case planDescription = "plan_description"
        case dietaryPreferences = "dietary_preferences"
        case allergies
        case dislikes
        case calorieTarget = "calorie_target"
        case weekStartDate = "week_start_date"
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
    let weekStartDate: Date
    var dailyMeals: [DailyMealSlots]
    
    init(weekStartDate: Date = Date()) {
        self.weekStartDate = weekStartDate
        self.dailyMeals = []
        
        // Initialize 7 days starting from Monday
        let calendar = Calendar.mondayFirst
        let actualWeekStart = weekStartDate.startOfWeek() // Ensure we start from Monday
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: actualWeekStart) {
                // Use custom day names array starting with Monday
                let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
                let dayName = dayNames[i]
                dailyMeals.append(DailyMealSlots(day: dayName, date: date))
            }
        }
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
    let recipes: [String] // Recipe names that use this ingredient
    var isCompleted: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case ingredient
        case amount
        case unit
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

