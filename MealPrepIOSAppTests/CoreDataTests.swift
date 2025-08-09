//
//  CoreDataTests.swift
//  MealPrepIOSAppTests
//
//  Created by AI Assistant on 7/21/25.
//

import Testing
import CoreData
import Foundation
@testable import MealPrepIOSApp

struct CoreDataTests {

    @Test("Recipe caching and retrieval")
    func testRecipeCaching() async throws {
        let cacheManager = RecipeCacheManager()

        // Create test recipe
        let testRecipe = Recipe(
            id: "test-1",
            name: "Test Recipe",
            description: "A test recipe",
            ingredients: [
                Ingredient(name: "Test ingredient", amount: "1", unit: "cup", notes: nil)
            ],
            instructions: ["Test instructions"],
            nutritionInfo: nil,
            cuisine: "Test",
            prepTime: 10,
            cookTime: 20,
            difficulty: .easy,
            avgRating: 4.5,
            ratingCount: 10,
            imageUrl: nil,
            tags: ["test"],
            createdByUser: "Test User",
            createdByUserId: "user-1",
            createdAt: Date(),
            updatedAt: Date()
        )

        // Save recipe
        try await cacheManager.save([testRecipe])

        // Fetch recipes
        let cachedRecipes = try await cacheManager.fetch()
        #expect(cachedRecipes.count >= 1)

        // Find our test recipe
        let foundRecipe = cachedRecipes.first { $0.id == "test-1" }
        #expect(foundRecipe != nil)
        #expect(foundRecipe?.name == "Test Recipe")

        // Test search
        let searchResults = try await cacheManager.searchRecipes(query: "Test")
        #expect(searchResults.count >= 1)

        // Clean up
        try await cacheManager.delete("test-1")
    }

    @Test("User caching and current user management")
    func testUserCaching() async throws {
        let cacheManager = UserCacheManager()

        // Create test user
        let testUser = User(
            id: "user-1",
            username: "testuser",
            email: "test@example.com",
            displayName: "Test User",
            dietaryPreferences: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        // Save as current user
        try await cacheManager.saveCurrentUser(testUser)

        // Retrieve current user
        let currentUser = try await cacheManager.getCurrentUser()
        #expect(currentUser != nil)
        #expect(currentUser?.id == "user-1")
        #expect(currentUser?.username == "testuser")

        // Clear current user
        try await cacheManager.clearCurrentUser()
        let clearedUser = try await cacheManager.getCurrentUser()
        #expect(clearedUser == nil)
    }

    @Test("Recipe filtering by difficulty and cuisine")
    func testRecipeFiltering() async throws {
        let cacheManager = RecipeCacheManager()

        // Create test recipes with different properties
        let easyRecipe = Recipe(
            id: "easy-1",
            name: "Easy Recipe",
            description: "An easy recipe",
            ingredients: [],
            instructions: ["Easy instructions"],
            nutritionInfo: nil,
            cuisine: "Italian",
            prepTime: 5,
            cookTime: 10,
            difficulty: .easy,
            avgRating: 4.0,
            ratingCount: 5,
            imageUrl: nil,
            tags: [],
            createdByUser: "Test User",
            createdByUserId: "user-1",
            createdAt: Date(),
            updatedAt: Date()
        )

        let hardRecipe = Recipe(
            id: "hard-1",
            name: "Hard Recipe",
            description: "A hard recipe",
            ingredients: [],
            instructions: ["Complex instructions"],
            nutritionInfo: nil,
            cuisine: "French",
            prepTime: 30,
            cookTime: 60,
            difficulty: .hard,
            avgRating: 5.0,
            ratingCount: 2,
            imageUrl: nil,
            tags: [],
            createdByUser: "Test User",
            createdByUserId: "user-1",
            createdAt: Date(),
            updatedAt: Date()
        )

        // Save recipes
        try await cacheManager.save([easyRecipe, hardRecipe])

        // Test difficulty filtering
        let easyRecipes = try await cacheManager.fetchRecipesByDifficulty(.easy)
        #expect(easyRecipes.contains { $0.id == "easy-1" })

        // Test cuisine filtering
        let italianRecipes = try await cacheManager.fetchRecipesByCuisine("Italian")
        #expect(italianRecipes.contains { $0.id == "easy-1" })

        // Clean up
        try await cacheManager.delete("easy-1")
        try await cacheManager.delete("hard-1")
    }
}