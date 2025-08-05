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
    let protein: Int?       // Changed from String to Int for backend validation
    let carbohydrates: Int? // Changed from String to Int for backend validation
    let fat: Int?           // Changed from String to Int for backend validation
    let fiber: Int?         // Changed from String to Int for backend validation
    let sodium: Int?        // Changed from String to Int for backend validation
    let sugar: Int?         // Changed from String to Int for backend validation
    let servings: Int?
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
}

// MARK: - Helper Extensions

extension AIGeneratedRecipe {
    /// Convert to Recipe model for display
    func toRecipe(id: String = UUID().uuidString, createdByUser: String = "AI Generated") -> Recipe {
        let nutrition = NutritionInfo(
            calories: nutritionInfo.calories != nil ? String(nutritionInfo.calories!) : nil,
            protein: nutritionInfo.protein != nil ? String(nutritionInfo.protein!) : nil,
            carbohydrates: nutritionInfo.carbohydrates != nil ? String(nutritionInfo.carbohydrates!) : nil,
            fat: nutritionInfo.fat != nil ? String(nutritionInfo.fat!) : nil,
            fiber: nutritionInfo.fiber != nil ? String(nutritionInfo.fiber!) : nil,
            sodium: nutritionInfo.sodium != nil ? String(nutritionInfo.sodium!) : nil,
            sugar: nutritionInfo.sugar != nil ? String(nutritionInfo.sugar!) : nil,
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
