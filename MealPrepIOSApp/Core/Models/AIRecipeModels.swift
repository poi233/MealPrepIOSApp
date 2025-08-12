//
//  AIRecipeModels.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/21/25.
//

import Foundation

// MARK: - AI Recipe Generation Request Models

struct AIRecipeGenerationRequest: Codable {
    let name: String
    let description: String?
    let cuisine: String?
    let difficulty: String?
    let prepTime: Int?
    let cookTime: Int?
    let mealType: String?
    let dietaryRestrictions: [String]?
    let ingredients: [String]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case cuisine
        case difficulty
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case mealType = "meal_type"
        case dietaryRestrictions = "dietary_restrictions"
        case ingredients
    }
    
    init(name: String, description: String? = nil, cuisine: String? = nil, 
         difficulty: String? = nil, prepTime: Int? = nil, cookTime: Int? = nil,
         mealType: String? = nil, dietaryRestrictions: [String]? = nil, 
         ingredients: [String]? = nil) {
        self.name = name
        self.description = description
        self.cuisine = cuisine
        self.difficulty = difficulty
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.mealType = mealType
        self.dietaryRestrictions = dietaryRestrictions
        self.ingredients = ingredients
    }
}

// MARK: - AI Generated Recipe Response

struct AIGeneratedRecipe: Codable {
    let name: String
    let description: String
    let cuisine: String
    let difficulty: Difficulty
    let prepTime: Int
    let cookTime: Int
    let imageUrl: String?
    let ingredients: [AIIngredient]  // Use AI-specific ingredient structure
    let instructions: [String]  // New format: ["1. 准备工作...", "2. 开始烹饪..."]
    let nutritionInfo: AINutritionInfo
    let tags: [String]

    // Regular initializer for creating AIGeneratedRecipe instances
    init(name: String, description: String, cuisine: String, difficulty: Difficulty,
         prepTime: Int, cookTime: Int, imageUrl: String?, ingredients: [AIIngredient],
         instructions: [String], nutritionInfo: AINutritionInfo, tags: [String]) {
        self.name = name
        self.description = description
        self.cuisine = cuisine
        self.difficulty = difficulty
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.imageUrl = imageUrl
        self.ingredients = ingredients
        self.instructions = instructions
        self.nutritionInfo = nutritionInfo
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case cuisine
        case difficulty
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case imageUrl = "image_url"
        case ingredients
        case instructions
        case nutritionInfo = "nutrition_info"
        case tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // DEBUG: Print all available keys in the container
        print("[DEBUG] AIGeneratedRecipe - Available keys in decoder: \(container.allKeys.map { $0.stringValue })")

        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        cuisine = try container.decode(String.self, forKey: .cuisine)
        difficulty = try container.decode(Difficulty.self, forKey: .difficulty)
        prepTime = try container.decode(Int.self, forKey: .prepTime)
        cookTime = try container.decode(Int.self, forKey: .cookTime)

        // DEBUG: Check if image_url key exists and what its value is
        if container.contains(.imageUrl) {
            let imageUrlValue = try container.decodeIfPresent(String.self, forKey: .imageUrl)
            print("[DEBUG] AIGeneratedRecipe - image_url key exists, value: '\(imageUrlValue ?? "nil string"))'")
            imageUrl = imageUrlValue
        } else {
            print("[DEBUG] AIGeneratedRecipe - image_url key does NOT exist in response")
            imageUrl = nil
        }

        ingredients = try container.decode([AIIngredient].self, forKey: .ingredients)
        instructions = try container.decode([String].self, forKey: .instructions)
        nutritionInfo = try container.decode(AINutritionInfo.self, forKey: .nutritionInfo)
        tags = try container.decode([String].self, forKey: .tags)

        print("[DEBUG] AIGeneratedRecipe decoded - final imageUrl: '\(imageUrl ?? "nil")'")
        print("[DEBUG] AIGeneratedRecipe decoded - name: '\(name)'")
    }

    /// Custom encoding to ensure image_url field is always included for backend validation
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(cuisine, forKey: .cuisine)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(prepTime, forKey: .prepTime)
        try container.encode(cookTime, forKey: .cookTime)

        // Always encode image_url, even if nil - use empty string for backend compatibility
        try container.encode(imageUrl ?? "", forKey: .imageUrl)

        try container.encode(ingredients, forKey: .ingredients)
        try container.encode(instructions, forKey: .instructions)
        try container.encode(nutritionInfo, forKey: .nutritionInfo)
        try container.encode(tags, forKey: .tags)

        print("[DEBUG] AIGeneratedRecipe encoded - imageUrl field: '\(imageUrl ?? "")'")
    }
}

struct AIIngredient: Codable {
    let name: String
    let amount: String

    // Regular initializer for creating AIIngredient instances
    init(name: String, amount: String) {
        self.name = name
        self.amount = amount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        amount = try container.decode(String.self, forKey: .amount)
    }

    enum CodingKeys: String, CodingKey {
        case name
        case amount
    }

    /// Convert to standard Ingredient
    func toIngredient() -> Ingredient {
        return Ingredient(name: name, amount: amount, unit: "", notes: nil)
    }
}

struct AINutritionInfo: Codable {
    let calories: Int?
    let protein: String?    // Backend returns strings with units like "12g"
    let carbohydrates: String? // Backend returns strings with units like "15g"
    let fat: String?        // Backend returns strings with units like "20g"
    let fiber: String?      // Backend returns strings with units like "3g"
    let sodium: String?     // Backend returns strings with units like "250mg"
    let sugar: String?      // Backend returns strings with units like "8g"
    let servings: Int?
    
    /// Clean nutrition values by removing units and extracting numeric values
    /// for API submission (create-recipe-from-ai requires pure numbers)
    func toCleanedNutritionInfo() -> [String: Any] {
        var cleaned: [String: Any] = [:]
        
        // Calories is already an Int
        if let calories = calories {
            cleaned["calories"] = calories
        }
        
        // Helper function to extract numbers from strings like "12g", "250mg"
        func extractNumber(from text: String?) -> Double? {
            guard let text = text else { return nil }
            
            // Use regex to extract the first number (including decimals)
            let pattern = #"(\d+\.?\d*)"#
            if let range = text.range(of: pattern, options: .regularExpression) {
                let numberString = String(text[range])
                return Double(numberString)
            }
            return nil
        }
        
        // Extract numbers from unit strings using safe optional mapping
        if let proteinValue = extractNumber(from: protein) {
            cleaned["protein"] = proteinValue
        }
        if let carbsValue = extractNumber(from: carbohydrates) {
            cleaned["carbohydrates"] = carbsValue
        }
        if let fatValue = extractNumber(from: fat) {
            cleaned["fat"] = fatValue
        }
        if let fiberValue = extractNumber(from: fiber) {
            cleaned["fiber"] = fiberValue
        }
        if let sodiumValue = extractNumber(from: sodium) {
            cleaned["sodium"] = sodiumValue
        }
        if let sugarValue = extractNumber(from: sugar) {
            cleaned["sugar"] = sugarValue
        }
        
        // Servings is already an Int
        if let servings = servings {
            cleaned["servings"] = servings
        }
        
        return cleaned
    }
}

// MARK: - Create Recipe From AI Request

struct CreateRecipeFromAIRequest: Codable {
    let aiRecipeData: AIGeneratedRecipe
    let saveToAccount: Bool
    let addToMealPlan: String?
    let mealPlanDay: Int?
    let mealPlanType: MealType?

    enum CodingKeys: String, CodingKey {
        case aiRecipeData = "ai_recipe_data"
        case saveToAccount = "save_to_account"
        case addToMealPlan = "add_to_meal_plan"
        case mealPlanDay = "meal_plan_day"
        case mealPlanType = "meal_plan_type"
    }
    
    /// Custom encoding to clean nutrition data before sending to backend
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Helper function to extract numbers from strings like "12g", "250mg"
        func extractNumber(from text: String?) -> Double? {
            guard let text = text else { return nil }
            
            // Use regex to extract the first number (including decimals)
            let pattern = #"(\d+\.?\d*)"#
            if let range = text.range(of: pattern, options: .regularExpression) {
                let numberString = String(text[range])
                return Double(numberString)
            }
            return nil
        }
        
        // Create a temporary AIGeneratedRecipe with cleaned nutrition info
        let cleanedNutrition = AINutritionInfo(
            calories: aiRecipeData.nutritionInfo.calories,
            protein: extractNumber(from: aiRecipeData.nutritionInfo.protein).map { String($0) },
            carbohydrates: extractNumber(from: aiRecipeData.nutritionInfo.carbohydrates).map { String($0) },
            fat: extractNumber(from: aiRecipeData.nutritionInfo.fat).map { String($0) },
            fiber: extractNumber(from: aiRecipeData.nutritionInfo.fiber).map { String($0) },
            sodium: extractNumber(from: aiRecipeData.nutritionInfo.sodium).map { String($0) },
            sugar: extractNumber(from: aiRecipeData.nutritionInfo.sugar).map { String($0) },
            servings: aiRecipeData.nutritionInfo.servings
        )
        
        let cleanedAIRecipe = AIGeneratedRecipe(
            name: aiRecipeData.name,
            description: aiRecipeData.description,
            cuisine: aiRecipeData.cuisine,
            difficulty: aiRecipeData.difficulty,
            prepTime: aiRecipeData.prepTime,
            cookTime: aiRecipeData.cookTime,
            imageUrl: aiRecipeData.imageUrl,
            ingredients: aiRecipeData.ingredients,
            instructions: aiRecipeData.instructions,
            nutritionInfo: cleanedNutrition,
            tags: aiRecipeData.tags
        )
        
        try container.encode(cleanedAIRecipe, forKey: .aiRecipeData)
        try container.encode(saveToAccount, forKey: .saveToAccount)
        try container.encodeIfPresent(addToMealPlan, forKey: .addToMealPlan)
        try container.encodeIfPresent(mealPlanDay, forKey: .mealPlanDay)
        try container.encodeIfPresent(mealPlanType, forKey: .mealPlanType)
    }
}

// MARK: - Helper Extensions

extension AIGeneratedRecipe {
    /// Convert to Recipe model for display
    func toRecipe(id: String = UUID().uuidString, createdByUser: String = "AI Generated") -> Recipe {
        let nutrition = NutritionInfo(
            calories: nutritionInfo.calories.map { String($0) },
            protein: nutritionInfo.protein,      // Already a String from backend
            carbohydrates: nutritionInfo.carbohydrates, // Already a String from backend
            fat: nutritionInfo.fat,              // Already a String from backend
            fiber: nutritionInfo.fiber,          // Already a String from backend
            sodium: nutritionInfo.sodium,        // Already a String from backend
            sugar: nutritionInfo.sugar,          // Already a String from backend
            servings: nutritionInfo.servings
        )

        // Convert AI ingredients to standard ingredients
        let standardIngredients = ingredients.map { $0.toIngredient() }

        return Recipe(
            id: id,
            name: name,
            description: description,
            ingredients: standardIngredients,
            instructions: instructions, // Keep as array
            nutritionInfo: nutrition,
            cuisine: cuisine,
            prepTime: prepTime,
            cookTime: cookTime,
            difficulty: difficulty,
            avgRating: 0.0,
            ratingCount: 0,
            imageUrl: imageUrl, // Use AI-generated image URL
            tags: tags,
            createdByUser: createdByUser,
            createdByUserId: "ai-generated"
        )
    }
}

// MARK: - AI Recipe Creation Response

struct CreateRecipeFromAIResponse: Codable {
    let success: Bool
    let recipe: Recipe
    let status: String

    enum CodingKeys: String, CodingKey {
        case success
        case recipe
        case status
    }
}

// MARK: - AI Recipe Generation State

enum AIRecipeGenerationState {
    case idle
    case generating
    case preview(AIGeneratedRecipe)
    case creating
    case success(Recipe)
    case error(String)
}
