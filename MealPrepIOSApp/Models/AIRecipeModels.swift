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
    let difficulty: Difficulty?
    let prepTime: Int?
    let cookTime: Int?
    let mealType: MealType?
    let dietaryRestrictions: [String]?
    let ingredients: [String]?
    let additionalRequirements: String?
    
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
        case additionalRequirements = "additional_requirements"
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
    let ingredients: [String]  // AI returns ingredients as strings, we'll parse them
    let instructions: String
    let nutritionInfo: AINutritionInfo
    let tags: [String]
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case cuisine
        case difficulty
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case ingredients
        case instructions
        case nutritionInfo = "nutrition_info"
        case tags
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
    /// Convert AI ingredients (strings) to structured Ingredient objects
    var parsedIngredients: [Ingredient] {
        return ingredients.compactMap { ingredientString in
            // Parse ingredient strings like "2 cups flour" or "1 lb ground beef, lean"
            let parts = ingredientString.components(separatedBy: CharacterSet.whitespaces)
            guard parts.count >= 2 else {
                // If parsing fails, create ingredient with name only
                return Ingredient(name: ingredientString, amount: "", unit: "")
            }
            
            let amount = parts[0]
            let unit = parts.count > 2 ? parts[1] : ""
            let name = parts.dropFirst(unit.isEmpty ? 1 : 2).joined(separator: " ")
            
            // Extract notes if there's a comma
            let components = name.components(separatedBy: ",")
            let ingredientName = components[0].trimmingCharacters(in: .whitespaces)
            let notes = components.count > 1 ? components[1].trimmingCharacters(in: .whitespaces) : nil
            
            return Ingredient(
                name: ingredientName,
                amount: amount,
                unit: unit,
                notes: notes
            )
        }
    }
    
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
        
        return Recipe(
            id: id,
            name: name,
            description: description,
            ingredients: parsedIngredients,
            instructions: instructions,
            nutritionInfo: nutrition,
            cuisine: cuisine,
            prepTime: prepTime,
            cookTime: cookTime,
            difficulty: difficulty,
            avgRating: 0.0,
            ratingCount: 0,
            imageUrl: nil,
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