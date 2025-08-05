//
//  RecipeStub.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 8/2/25.
//

import Foundation

// MARK: - RecipeStub Model
/**
 * Lightweight recipe representation for meal plan generation phase.
 * Contains minimal information needed for initial display before user applies to meal plan.
 * Unified format between iOS frontend and backend generateMealPlan response.
 * 
 * Optimized for fast AI generation with reduced optional fields and better defaults.
 */
struct RecipeStub: Codable, Identifiable, Hashable {
    let id: String                     // Unique ID: UUID for AI-generated, database ID for existing
    let name: String                   // Recipe name (required)
    let cuisine: String                // Cuisine type with default fallback
    let description: String            // Short description for preview
    let estimatedCalories: Int         // Estimated calories per serving (default: 300)
    let estimatedPrepTime: Int         // Estimated prep time in minutes (default: 30)
    let imageUrl: String?              // Thumbnail image URL (only optional field)
    let tags: [String]                 // Recipe tags for filtering and display
    let difficulty: Difficulty         // Recipe difficulty level
    let isAIGenerated: Bool            // Track if this is AI-generated or existing recipe
    
    // Custom coding keys to match backend RecipeStubSerializer exactly
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case cuisine
        case description
        case estimatedCalories = "estimated_calories"
        case estimatedPrepTime = "estimated_prep_time"
        case imageUrl = "image_url"
        case tags
        // Note: difficulty and isAIGenerated are iOS-only fields, not in backend contract
        case difficulty
        case isAIGenerated = "is_ai_generated"
    }
    
    init(
        id: String? = nil,
        name: String,
        cuisine: String = "国际",
        description: String? = nil,
        estimatedCalories: Int = 300,
        estimatedPrepTime: Int = 30,
        imageUrl: String? = nil,
        tags: [String] = [],
        difficulty: Difficulty = .medium,
        isAIGenerated: Bool = true
    ) {
        self.id = id ?? UUID().uuidString
        self.name = name
        self.cuisine = cuisine
        self.description = description ?? "美味的\(name)"
        self.estimatedCalories = estimatedCalories
        self.estimatedPrepTime = estimatedPrepTime
        self.imageUrl = imageUrl
        self.tags = tags
        self.difficulty = difficulty
        self.isAIGenerated = isAIGenerated
    }
    
    /// Initialize from backend API response (RecipeStubSerializer)
    /// Handles the exact backend contract with proper null/optional field handling
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle id field - backend allows null, but we need a valid ID
        if let idString = try? container.decodeIfPresent(String.self, forKey: .id), 
           !idString.isEmpty {
            id = idString
        } else if let idInt = try? container.decodeIfPresent(Int.self, forKey: .id) {
            id = String(idInt)
        } else {
            // Generate UUID for AI-generated recipes when id is null/missing
            id = UUID().uuidString
        }
        
        // Required field in backend contract
        name = try container.decode(String.self, forKey: .name)
        
        // Optional fields with proper defaults (backend allows null)
        if let cuisineValue = try container.decodeIfPresent(String.self, forKey: .cuisine),
           !cuisineValue.isEmpty {
            cuisine = cuisineValue
        } else {
            cuisine = "国际"  // Default cuisine
        }
        
        if let descValue = try container.decodeIfPresent(String.self, forKey: .description),
           !descValue.isEmpty {
            description = descValue
        } else {
            description = "美味的\(name)"  // Generate default description
        }
        
        estimatedCalories = try container.decodeIfPresent(Int.self, forKey: .estimatedCalories) ?? 300
        estimatedPrepTime = try container.decodeIfPresent(Int.self, forKey: .estimatedPrepTime) ?? 30
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        
        // iOS-only fields with defaults (not in backend contract)
        difficulty = try container.decodeIfPresent(Difficulty.self, forKey: .difficulty) ?? .medium
        isAIGenerated = try container.decodeIfPresent(Bool.self, forKey: .isAIGenerated) ?? true
    }
    
    /// Encode to backend API format
    /// Only includes fields that are part of the backend RecipeStubSerializer contract
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Only encode id if it's not a generated UUID (backend expects null for AI-generated)
        if !isAIGenerated || !id.contains("-") {
            try container.encode(id, forKey: .id)
        } else {
            try container.encodeNil(forKey: .id)  // Send null for AI-generated recipes
        }
        
        try container.encode(name, forKey: .name)
        try container.encode(cuisine.isEmpty ? nil : cuisine, forKey: .cuisine)
        try container.encode(description.isEmpty ? nil : description, forKey: .description)
        try container.encode(estimatedCalories, forKey: .estimatedCalories)
        try container.encode(estimatedPrepTime, forKey: .estimatedPrepTime)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encode(tags.isEmpty ? nil : tags, forKey: .tags)
        
        // iOS-only fields - include for internal iOS communication
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(isAIGenerated, forKey: .isAIGenerated)
    }
    
    // MARK: - Computed Properties
    
    /// Display string for estimated prep time
    var prepTimeDisplay: String {
        return "\(estimatedPrepTime)分钟"
    }
    
    /// Display string for estimated calories
    var caloriesDisplay: String {
        return "\(estimatedCalories) 卡路里"
    }
    
    /// Cuisine display (no fallback needed as it's non-optional)
    var cuisineDisplay: String {
        return cuisine
    }
    
    /// Tags display (no fallback needed as it's non-optional)
    var tagsDisplay: [String] {
        return tags
    }
    
    /// Description display (no fallback needed as it's non-optional)
    var descriptionDisplay: String {
        return description
    }
    
    /// Difficulty display string
    var difficultyDisplay: String {
        switch difficulty {
        case .easy: return "简单"
        case .medium: return "中等"
        case .hard: return "困难"
        }
    }
    
    // MARK: - Hashable Implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }
    
    static func == (lhs: RecipeStub, rhs: RecipeStub) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - RecipeStub Extensions

extension RecipeStub {
    /// Check if this stub represents an existing database recipe
    var isExistingRecipe: Bool {
        return !isAIGenerated
    }
    
    /// Create a RecipeStub from a full Recipe object
    static func fromRecipe(_ recipe: Recipe) -> RecipeStub {
        return RecipeStub(
            id: recipe.id,
            name: recipe.name,
            cuisine: recipe.cuisine?.isEmpty == false ? recipe.cuisine! : "国际",
            description: recipe.description.isEmpty ? "美味的\(recipe.name)" : recipe.description,
            estimatedCalories: {
                if let nutritionInfo = recipe.nutritionInfo,
                   let caloriesString = nutritionInfo.calories,
                   let calories = Int(caloriesString) {
                    return calories
                }
                return 300
            }(),
            estimatedPrepTime: recipe.prepTime,
            imageUrl: recipe.imageUrl,
            tags: recipe.tags,
            difficulty: recipe.difficulty,
            isAIGenerated: false
        )
    }
    
    /// Create a basic AI-generated RecipeStub with just name and cuisine
    static func aiGenerated(name: String, cuisine: String = "国际") -> RecipeStub {
        return RecipeStub(
            name: name,
            cuisine: cuisine,
            isAIGenerated: true
        )
    }
    
    /// Convert RecipeStub to full Recipe object for WeeklyMealGrid compatibility
    /// Used when applying AI-generated meal plans to the weekly grid
    func toRecipe() -> Recipe {
        return Recipe(
            id: self.id,
            name: self.name,
            description: self.description,
            ingredients: [], // Empty for stubs - will be populated when user applies
            instructions: [], // Empty for stubs - will be populated when user applies
            nutritionInfo: NutritionInfo(
                calories: String(self.estimatedCalories),
                protein: nil,
                carbohydrates: nil,
                fat: nil,
                fiber: nil,
                sodium: nil,
                sugar: nil,
                servings: 1
            ),
            cuisine: self.cuisine,
            prepTime: self.estimatedPrepTime,
            cookTime: 0, // Default for stubs
            difficulty: self.difficulty,
            avgRating: 0.0, // Default rating for stubs
            ratingCount: 0, // Default rating count for stubs
            imageUrl: self.imageUrl,
            tags: self.tags,
            createdByUser: "AI Generated", // Default for AI-generated stubs
            createdByUserId: "ai", // Default user ID for AI-generated content
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    /// Convert RecipeStub to AIGeneratedRecipe for create-recipe-from-ai API
    /// Used when generating full recipe details from AI meal plan stubs
    func toAIGeneratedRecipe() -> AIGeneratedRecipe {
        // Create basic AI ingredients placeholder - will be enhanced by AI
        let basicIngredients = [
            AIIngredient(name: "主要食材", amount: "适量"),
            AIIngredient(name: "调料", amount: "适量")
        ]
        
        // Create basic AI nutrition info from estimated values
        let aiNutrition = AINutritionInfo(
            calories: self.estimatedCalories,
            protein: nil, // Will be populated by AI
            carbohydrates: nil, // Will be populated by AI
            fat: nil, // Will be populated by AI
            fiber: nil, // Will be populated by AI
            sodium: nil, // Will be populated by AI
            sugar: nil, // Will be populated by AI
            servings: 1
        )
        
        // Create basic instruction placeholder - will be enhanced by AI
        let basicInstructions = [
            "1. 准备所需食材",
            "2. 按照传统做法烹饪",
            "3. 调味并完成制作"
        ]
        
        return AIGeneratedRecipe(
            name: self.name,
            description: self.description,
            cuisine: self.cuisine,
            difficulty: self.difficulty,
            prepTime: self.estimatedPrepTime,
            cookTime: max(15, self.estimatedPrepTime / 2), // Estimate cook time as half of prep time, minimum 15 min
            imageUrl: nil, // Let backend auto-generate from Pexels API
            ingredients: basicIngredients,
            instructions: basicInstructions,
            nutritionInfo: aiNutrition,
            tags: self.tags
        )
    }
}

// MARK: - Lightweight Daily Meal Structure

/**
 * Daily meal structure using RecipeStub for lightweight meal plan generation.
 * Replaces the heavy DailyMeal structure that uses full Recipe objects.
 * Matches backend LightweightDailyMealSerializer API contract exactly.
 * Used for AI-generated meal plans with recipe stubs for latency optimization.
 */
struct LightweightDailyMeal: Codable, Identifiable {
    let id = UUID()
    let day: String                    // Day name (matches backend - "Monday", "星期一")
    let breakfast: [RecipeStub]        // Breakfast recipe stubs (matches backend)
    let lunch: [RecipeStub]            // Lunch recipe stubs (matches backend)  
    let dinner: [RecipeStub]           // Dinner recipe stubs (matches backend)
    
    enum CodingKeys: String, CodingKey {
        case day
        case breakfast
        case lunch
        case dinner
        // Note: id is excluded from coding to match backend contract
    }
    
    init(day: String, breakfast: [RecipeStub] = [], lunch: [RecipeStub] = [], dinner: [RecipeStub] = []) {
        self.day = day
        self.breakfast = breakfast
        self.lunch = lunch
        self.dinner = dinner
    }
    
    // MARK: - Backend Compatibility Initializer
    
    /// Initialize from backend API response (GeneratedMealPlanSerializer.lightweight_daily_meals)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        day = try container.decode(String.self, forKey: .day)
        breakfast = try container.decodeIfPresent([RecipeStub].self, forKey: .breakfast) ?? []
        lunch = try container.decodeIfPresent([RecipeStub].self, forKey: .lunch) ?? []
        dinner = try container.decodeIfPresent([RecipeStub].self, forKey: .dinner) ?? []
    }
    
    /// Encode to backend API format
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(day, forKey: .day)
        try container.encode(breakfast, forKey: .breakfast)
        try container.encode(lunch, forKey: .lunch)
        try container.encode(dinner, forKey: .dinner)
        // Note: id is intentionally excluded to match backend API contract
    }
    
    // MARK: - Computed Properties for UI Display
    
    /// Total estimated calories for the day
    var totalCalories: Int {
        let breakfastCal = breakfast.reduce(0) { $0 + $1.estimatedCalories }
        let lunchCal = lunch.reduce(0) { $0 + $1.estimatedCalories }
        let dinnerCal = dinner.reduce(0) { $0 + $1.estimatedCalories }
        return breakfastCal + lunchCal + dinnerCal
    }
    
    /// Total estimated prep time for the day
    var totalPrepTime: Int {
        let breakfastTime = breakfast.reduce(0) { $0 + $1.estimatedPrepTime }
        let lunchTime = lunch.reduce(0) { $0 + $1.estimatedPrepTime }
        let dinnerTime = dinner.reduce(0) { $0 + $1.estimatedPrepTime }
        return breakfastTime + lunchTime + dinnerTime
    }
    
    /// All unique cuisines for the day
    var cuisines: [String] {
        let allCuisines = breakfast.map { $0.cuisine } + lunch.map { $0.cuisine } + dinner.map { $0.cuisine }
        return Array(Set(allCuisines)).sorted()
    }
    
    /// Check if the day has any meals planned
    var hasAnyMeals: Bool {
        return !breakfast.isEmpty || !lunch.isEmpty || !dinner.isEmpty
    }
    
    /// Check if the day is fully planned (all three meals)
    var isFullyPlanned: Bool {
        return !breakfast.isEmpty && !lunch.isEmpty && !dinner.isEmpty
    }
}

// MARK: - Apply Meal Request Models

/**
 * Request model for applying a recipe stub to user's actual meal plan.
 * Matches backend ApplyMealRequestSerializer exactly.
 * Sent when user clicks "Apply to Plan" button.
 */
struct ApplyMealRequest: Codable {
    let recipeStub: RecipeStub         // The stub to convert to full recipe (matches backend)
    let mealPlanId: String?            // Target meal plan ID (optional, matches backend UUID field)
    let dayOfWeek: Int                 // Day of week (0=Monday, 6=Sunday, matches backend)
    let mealType: String               // "breakfast", "lunch", "dinner", "snack" (matches backend)
    let servingSize: Double            // Serving size adjustment (required in backend, default 1.0)
    let saveToAccount: Bool            // Whether to save recipe to user's account (matches backend)
    
    enum CodingKeys: String, CodingKey {
        case recipeStub = "recipe_stub"
        case mealPlanId = "meal_plan_id"
        case dayOfWeek = "day_of_week"
        case mealType = "meal_type"
        case servingSize = "serving_size"
        case saveToAccount = "save_to_account"
    }
    
    init(
        recipeStub: RecipeStub,
        mealPlanId: String? = nil,
        dayOfWeek: Int,
        mealType: String,
        servingSize: Double = 1.0,
        saveToAccount: Bool = true
    ) {
        self.recipeStub = recipeStub
        self.mealPlanId = mealPlanId
        self.dayOfWeek = dayOfWeek
        self.mealType = mealType
        self.servingSize = servingSize
        self.saveToAccount = saveToAccount
    }
}

/**
 * Response model for apply meal operation.
 * Matches backend ApplyMealResponseSerializer exactly.
 * Returns the complete recipe that was created and added to meal plan.
 */
struct ApplyMealResponse: Codable {
    let success: Bool                  // Operation success status (matches backend)
    let recipe: Recipe?                // Complete recipe that was created (optional, matches backend)
    let mealPlanItem: MealPlanItem?    // Created meal plan item (optional, matches backend)
    let message: String?               // Success/error message (optional, matches backend)
    
    enum CodingKeys: String, CodingKey {
        case success
        case recipe
        case mealPlanItem = "meal_plan_item"
        case message
    }
}

// MARK: - Sample Data

extension RecipeStub {
    static let sampleStub = RecipeStub(
        name: "蒜蓉西兰花",
        cuisine: "中式",
        description: "清爽健康的蒜蓉炒西兰花",
        estimatedCalories: 120,
        estimatedPrepTime: 15,
        imageUrl: nil,
        tags: ["健康", "素食", "快手菜"],
        difficulty: .easy,
        isAIGenerated: true
    )
    
    static let sampleExistingStub = RecipeStub(
        id: "recipe-123",  // Existing database recipe
        name: "红烧肉",
        cuisine: "中式",
        description: "经典上海红烧肉",
        estimatedCalories: 450,
        estimatedPrepTime: 60,
        imageUrl: "https://example.com/hongshaorou.jpg",
        tags: ["经典", "肉类", "下饭菜"],
        difficulty: .medium,
        isAIGenerated: false
    )
}

extension LightweightDailyMeal {
    static let sampleDay = LightweightDailyMeal(
        day: "Monday",
        breakfast: [RecipeStub.sampleStub],
        lunch: [RecipeStub.sampleExistingStub],
        dinner: [RecipeStub.sampleStub, RecipeStub.sampleExistingStub]
    )
}