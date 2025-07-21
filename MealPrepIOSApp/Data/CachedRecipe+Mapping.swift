//
//  CachedRecipe+Mapping.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/21/25.
//

import Foundation
import CoreData

extension CachedRecipe {
    
    // MARK: - Convert from Recipe to CachedRecipe
    func fromRecipe(_ recipe: Recipe) {
        self.id = recipe.id
        self.name = recipe.name
        self.recipeDescription = recipe.description
        self.imageUrl = recipe.imageUrl
        self.prepTime = Int32(recipe.prepTime)
        self.cookTime = Int32(recipe.cookTime)
        self.totalTime = Int32(recipe.totalTime)
        self.difficulty = recipe.difficulty.rawValue
        self.cuisine = recipe.cuisine
        self.avgRating = recipe.avgRating
        self.userId = recipe.createdByUserId
        
        // Convert ingredients array to JSON string
        if let ingredientsData = try? JSONEncoder().encode(recipe.ingredients),
           let ingredientsString = String(data: ingredientsData, encoding: .utf8) {
            self.ingredients = ingredientsString
        }
        
        // Store instructions directly as string
        self.instructions = recipe.instructions
        
        // Convert tags array to JSON string
        if let tagsData = try? JSONEncoder().encode(recipe.tags),
           let tagsString = String(data: tagsData, encoding: .utf8) {
            self.tags = tagsString
        }
        
        self.createdAt = recipe.createdAt
        self.updatedAt = recipe.updatedAt
    }
    
    // MARK: - Convert from CachedRecipe to Recipe
    func toRecipe() -> Recipe? {
        guard let id = self.id,
              let name = self.name,
              let description = self.recipeDescription,
              let difficultyString = self.difficulty,
              let difficulty = Difficulty(rawValue: difficultyString),
              let createdAt = self.createdAt,
              let updatedAt = self.updatedAt else {
            return nil
        }
        
        // Parse ingredients from JSON string
        var ingredients: [Ingredient] = []
        if let ingredientsString = self.ingredients,
           let ingredientsData = ingredientsString.data(using: .utf8) {
            ingredients = (try? JSONDecoder().decode([Ingredient].self, from: ingredientsData)) ?? []
        }
        
        // Get instructions as string
        let instructions = self.instructions ?? ""
        
        // Parse tags from JSON string
        var tags: [String] = []
        if let tagsString = self.tags,
           let tagsData = tagsString.data(using: .utf8) {
            tags = (try? JSONDecoder().decode([String].self, from: tagsData)) ?? []
        }
        
        return Recipe(
            id: id,
            name: name,
            description: description,
            ingredients: ingredients,
            instructions: instructions,
            nutritionInfo: nil, // Not cached for now
            cuisine: self.cuisine,
            prepTime: Int(self.prepTime),
            cookTime: Int(self.cookTime),
            difficulty: difficulty,
            avgRating: self.avgRating,
            ratingCount: 0, // Not cached for now
            imageUrl: self.imageUrl,
            tags: tags,
            createdByUser: "", // Not cached for now
            createdByUserId: self.userId ?? "",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}