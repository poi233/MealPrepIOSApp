//
//  Recipe.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/20/25.
//

import Foundation

// MARK: - Recipe Model
struct Recipe: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let ingredients: [Ingredient]
    let instructions: String
    let nutritionInfo: NutritionInfo?
    let cuisine: String?
    let prepTime: Int
    let cookTime: Int
    let difficulty: Difficulty
    let avgRating: Double
    let ratingCount: Int
    let imageUrl: String?
    let tags: [String]
    let createdByUser: String
    let createdByUserId: String
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case ingredients
        case instructions
        case nutritionInfo = "nutrition_info"
        case cuisine
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case difficulty
        case avgRating = "avg_rating"
        case ratingCount = "rating_count"
        case imageUrl = "image_url"
        case tags
        case createdByUser = "created_by_user"
        case createdByUserId = "created_by_user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Standard initializer for creating Recipe instances
    init(
        id: String,
        name: String,
        description: String,
        ingredients: [Ingredient],
        instructions: String,
        nutritionInfo: NutritionInfo? = nil,
        cuisine: String? = nil,
        prepTime: Int,
        cookTime: Int,
        difficulty: Difficulty,
        avgRating: Double,
        ratingCount: Int,
        imageUrl: String? = nil,
        tags: [String],
        createdByUser: String,
        createdByUserId: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.ingredients = ingredients
        self.instructions = instructions
        self.nutritionInfo = nutritionInfo
        self.cuisine = cuisine
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.difficulty = difficulty
        self.avgRating = avgRating
        self.ratingCount = ratingCount
        self.imageUrl = imageUrl
        self.tags = tags
        self.createdByUser = createdByUser
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
        
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        
        // Handle ingredients as either structured objects or string array (from AI generation)
        if let structuredIngredients = try? container.decode([Ingredient].self, forKey: .ingredients) {
            ingredients = structuredIngredients
        } else if let stringIngredients = try? container.decode([String].self, forKey: .ingredients) {
            // Parse string ingredients into structured format
            ingredients = stringIngredients.map { ingredientString in
                // Split ingredient string to extract components
                let components = ingredientString.components(separatedBy: " ")
                if components.count >= 2 {
                    let name = components.dropLast().joined(separator: " ")
                    let amountUnit = components.last ?? ""
                    return Ingredient(name: name, amount: "1", unit: amountUnit, notes: ingredientString)
                } else {
                    return Ingredient(name: ingredientString, amount: "1", unit: "", notes: nil)
                }
            }
        } else {
            throw DecodingError.dataCorruptedError(forKey: .ingredients, in: container, debugDescription: "Ingredients must be either structured objects or string array")
        }
        
        instructions = try container.decode(String.self, forKey: .instructions)
        nutritionInfo = try container.decodeIfPresent(NutritionInfo.self, forKey: .nutritionInfo)
        cuisine = try container.decodeIfPresent(String.self, forKey: .cuisine)
        prepTime = try container.decode(Int.self, forKey: .prepTime)
        cookTime = try container.decode(Int.self, forKey: .cookTime)
        difficulty = try container.decode(Difficulty.self, forKey: .difficulty)
        // Handle avgRating as either String or Double
        if let avgRatingDouble = try? container.decode(Double.self, forKey: .avgRating) {
            avgRating = avgRatingDouble
        } else if let avgRatingString = try? container.decode(String.self, forKey: .avgRating) {
            avgRating = Double(avgRatingString) ?? 0.0
        } else {
            avgRating = 0.0
        }
        ratingCount = try container.decode(Int.self, forKey: .ratingCount)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        tags = try container.decode([String].self, forKey: .tags)
        // Handle createdByUser field - use empty string if not present since API doesn't always return it
        createdByUser = try container.decodeIfPresent(String.self, forKey: .createdByUser) ?? ""
        createdByUserId = try container.decode(String.self, forKey: .createdByUserId)
        
        // Handle flexible date parsing for timestamps
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    var totalTime: Int {
        return prepTime + cookTime
    }
}

// MARK: - Recipe Components
struct Ingredient: Codable, Identifiable {
    let id = UUID()
    let name: String
    let amount: String
    let unit: String
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case amount
        case unit
        case notes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decode(String.self, forKey: .name)
        unit = try container.decode(String.self, forKey: .unit)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        
        // Handle amount as either String or Number
        if let amountString = try? container.decode(String.self, forKey: .amount) {
            amount = amountString
        } else if let amountDouble = try? container.decode(Double.self, forKey: .amount) {
            amount = String(amountDouble)
        } else if let amountInt = try? container.decode(Int.self, forKey: .amount) {
            amount = String(amountInt)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .amount, in: container, debugDescription: "Amount must be either String or Number")
        }
    }
    
    init(name: String, amount: String, unit: String, notes: String? = nil) {
        self.name = name
        self.amount = amount
        self.unit = unit
        self.notes = notes
    }
}

struct NutritionInfo: Codable {
    let calories: String?
    let protein: String?
    let carbohydrates: String?
    let fat: String?
    let fiber: String?
    let sodium: String?
    let sugar: String?
    let servings: Int?
    
    enum CodingKeys: String, CodingKey {
        case calories
        case protein
        case carbohydrates = "carbs"
        case fat
        case fiber
        case sodium
        case sugar
        case servings
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Helper function to decode flexible numeric/string values
        func decodeFlexibleString(for key: CodingKeys) -> String? {
            // Try numeric types first since they're more common in the API response
            if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
                return String(doubleValue)
            } else if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
                return String(intValue)
            } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
                return stringValue
            }
            return nil
        }
        
        // Decode all nutrition fields with flexible parsing
        calories = decodeFlexibleString(for: .calories)
        protein = decodeFlexibleString(for: .protein)
        carbohydrates = decodeFlexibleString(for: .carbohydrates)
        fat = decodeFlexibleString(for: .fat)
        fiber = decodeFlexibleString(for: .fiber)
        sodium = decodeFlexibleString(for: .sodium)
        sugar = decodeFlexibleString(for: .sugar)
        
        // Handle servings as flexible numeric value
        if let servingsDouble = try? container.decodeIfPresent(Double.self, forKey: .servings) {
            servings = Int(servingsDouble)
        } else if let servingsInt = try? container.decodeIfPresent(Int.self, forKey: .servings) {
            servings = servingsInt
        } else {
            servings = nil
        }
    }
    
    init(calories: String? = nil, protein: String? = nil, carbohydrates: String? = nil, fat: String? = nil, fiber: String? = nil, sodium: String? = nil, sugar: String? = nil, servings: Int? = nil) {
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.fiber = fiber
        self.sodium = sodium
        self.sugar = sugar
        self.servings = servings
    }
}

// Enums moved to SharedEnums.swift to avoid duplication

// MARK: - Recipe Request Models
struct CreateRecipeRequest: Codable {
    let name: String
    let description: String
    let ingredients: [Ingredient]
    let instructions: String
    let nutritionInfo: NutritionInfo?
    let cuisine: String?
    let prepTime: Int
    let cookTime: Int
    let difficulty: Difficulty
    let imageUrl: String?
    let tags: [String]
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case ingredients
        case instructions
        case nutritionInfo = "nutrition_info"
        case cuisine
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case difficulty
        case imageUrl = "image_url"
        case tags
    }
}

struct UpdateRecipeRequest: Codable {
    let name: String?
    let description: String?
    let ingredients: [Ingredient]?
    let instructions: String?
    let nutritionInfo: NutritionInfo?
    let cuisine: String?
    let prepTime: Int?
    let cookTime: Int?
    let difficulty: Difficulty?
    let imageUrl: String?
    let tags: [String]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case ingredients
        case instructions
        case nutritionInfo = "nutrition_info"
        case cuisine
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case difficulty
        case imageUrl = "image_url"
        case tags
    }
}

// MARK: - Recipe Filters
struct RecipeFilters: Codable {
    let search: String?
    let cuisine: String?
    let difficulty: Difficulty?
    let prepTimeMax: Int?
    let cookTimeMax: Int?
    let totalTimeMax: Int?
    let avgRatingMin: Double?
    let tags: [String]?
    let mealType: MealType?
    let myRecipes: Bool?
    
    enum CodingKeys: String, CodingKey {
        case search
        case cuisine
        case difficulty
        case prepTimeMax = "prep_time__lte"
        case cookTimeMax = "cook_time__lte"
        case totalTimeMax = "total_time__lte"
        case avgRatingMin = "avg_rating__gte"
        case tags
        case mealType = "meal_type"
        case myRecipes = "my_recipes"
    }
    
    init(search: String? = nil, cuisine: String? = nil, difficulty: Difficulty? = nil, prepTimeMax: Int? = nil, cookTimeMax: Int? = nil, totalTimeMax: Int? = nil, avgRatingMin: Double? = nil, tags: [String]? = nil, mealType: MealType? = nil, myRecipes: Bool? = nil) {
        self.search = search
        self.cuisine = cuisine
        self.difficulty = difficulty
        self.prepTimeMax = prepTimeMax
        self.cookTimeMax = cookTimeMax
        self.totalTimeMax = totalTimeMax
        self.avgRatingMin = avgRatingMin
        self.tags = tags
        self.mealType = mealType
        self.myRecipes = myRecipes
    }
}

// MARK: - Sample Data
extension Recipe {
    static let sampleRecipe = Recipe(
        id: "sample-recipe-1",
        name: "Grilled Chicken Breast",
        description: "Juicy grilled chicken breast with herbs and spices",
        ingredients: [
            Ingredient(name: "Chicken breast", amount: "2", unit: "pieces"),
            Ingredient(name: "Olive oil", amount: "2", unit: "tbsp"),
            Ingredient(name: "Salt", amount: "1", unit: "tsp"),
            Ingredient(name: "Black pepper", amount: "1/2", unit: "tsp")
        ],
        instructions: "1. Season chicken with salt and pepper\n2. Heat grill to medium-high\n3. Grill 6-7 minutes per side",
        nutritionInfo: NutritionInfo(
            calories: "320",
            protein: "45",
            carbohydrates: "0",
            fat: "15",
            fiber: "0",
            sodium: nil,
            sugar: "0",
            servings: 2
        ),
        cuisine: "American",
        prepTime: 10,
        cookTime: 15,
        difficulty: .easy,
        avgRating: 4.5,
        ratingCount: 24,
        imageUrl: nil,
        tags: ["protein", "healthy", "quick"],
        createdByUser: "Sample User",
        createdByUserId: "user-1",
        createdAt: Date(),
        updatedAt: Date()
    )
}

// MARK: - Sample Data
extension MealPlanItem {
    static let sample = MealPlanItem(
        id: 1,
        mealPlanId: "meal-plan-1",
        recipe: Recipe.sampleRecipe,
        recipeId: Recipe.sampleRecipe.id,
        dayOfWeek: 0,
        mealType: "breakfast",
        addedAt: Date()
    )
}

// MARK: - Paginated Response
struct PaginatedResponse<T: Codable>: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let totalPages: Int
    let currentPage: Int
    let pageSize: Int
    let results: [T]
    
    enum CodingKeys: String, CodingKey {
        case count
        case next
        case previous
        case totalPages = "total_pages"
        case currentPage = "current_page"
        case pageSize = "page_size"
        case results
    }
}