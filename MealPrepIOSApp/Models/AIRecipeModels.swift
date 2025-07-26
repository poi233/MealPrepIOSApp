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
}

struct AIIngredient: Codable {
    let name: String
    let amount: String
    
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
    let protein: String?
    let carbohydrates: String?
    let fat: String?
    let fiber: String?
    let sodium: String?
    let sugar: String?
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
            protein: nutritionInfo.protein,
            carbohydrates: nutritionInfo.carbohydrates,
            fat: nutritionInfo.fat,
            fiber: nutritionInfo.fiber,
            sodium: nutritionInfo.sodium,
            sugar: nutritionInfo.sugar,
            servings: nutritionInfo.servings
        )
        
        // Convert AI ingredients to standard ingredients
        let standardIngredients = ingredients.map { $0.toIngredient() }
        
        return Recipe(
            id: id,
            name: name,
            description: description,
            ingredients: standardIngredients,
            instructions: instructions.joined(separator: "\n"), // Join instruction array
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

// MARK: - AI Recipe Generation State

enum AIRecipeGenerationState {
    case idle
    case generating
    case preview(AIGeneratedRecipe)
    case creating
    case success(Recipe)
    case error(String)
}
