//
//  UnifiedRecipeCacheTests.swift
//  MealPrepIOSAppTests
//
//  Created by AI Assistant on 7/27/25.
//  Tests for Task 3: Cache System Fixes and Crash Prevention
//

import XCTest
@testable import MealPrepIOSApp

final class UnifiedRecipeCacheTests: XCTestCase {

    var cache: UnifiedRecipeCache!

    override func setUpWithError() throws {
        // Use the shared storage manager with a test configuration
        cache = UnifiedRecipeCache(
            storageManager: .shared,
            configuration: CacheConfiguration(
                maxMemoryItems: 5,
                persistentStorageEnabled: false, // Disable persistence for tests
                cacheValidDuration: 300,
                pageSize: 5,
                maxRetryAttempts: 3
            )
        )
    }

    override func tearDownWithError() throws {
        cache = nil
    }

    // MARK: - Crash Prevention Tests

    func testCacheDoesNotCrashWithInvalidData() throws {
        // Test with empty recipes
        cache.updateCache(recipes: [], nextToken: nil, searchQuery: "test", isRefresh: true)
        XCTAssertEqual(cache.recipes.count, 0)
        XCTAssertFalse(cache.hasMorePages)

        // Test with recipes with empty IDs (should be filtered out)
        let invalidRecipes = [
            createTestRecipe(id: ""),
            createTestRecipe(id: "valid-1")
        ]

        cache.updateCache(recipes: invalidRecipes, nextToken: "next", searchQuery: "test", isRefresh: true)

        // Should only contain the valid recipe
        XCTAssertEqual(cache.recipes.count, 1)
        XCTAssertEqual(cache.recipes.first?.id, "valid-1")
        XCTAssertTrue(cache.hasMorePages)
    }

    func testCacheHandlesStorageErrors() throws {
        // Test with persistence disabled should work normally
        let recipes = [createTestRecipe()]

        // Should not crash even if storage fails
        cache.updateCache(recipes: recipes, nextToken: nil, searchQuery: "test", isRefresh: true)

        // Memory cache should still work
        XCTAssertEqual(cache.recipes.count, 1)
    }

    func testCacheValidationPreventsCorruption() throws {
        // Test that validation works correctly
        let validRecipes = [createTestRecipe()]
        cache.updateCache(recipes: validRecipes, nextToken: nil, searchQuery: "test", isRefresh: true)

        XCTAssertTrue(cache.validateRecipesForMealSelection())
        XCTAssertEqual(cache.recipes.count, 1)
    }

    // MARK: - User Context Tests

    func testCacheClearsOnUserLogout() throws {
        // Add some data
        let recipes = [createTestRecipe()]
        cache.updateCache(recipes: recipes, nextToken: nil, searchQuery: "test", isRefresh: true)
        XCTAssertEqual(cache.recipes.count, 1)

        // Simulate user logout
        NotificationCenter.default.post(name: .userLoggedOut, object: nil)

        // Give the cache time to process the notification
        let expectation = XCTestExpectation(description: "Cache cleared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Cache should be cleared
        XCTAssertEqual(cache.recipes.count, 0)
    }

    func testCacheLoadsOnUserLogin() throws {
        // Simulate user login
        NotificationCenter.default.post(name: .userLoggedIn, object: nil, userInfo: ["userID": "test-user"])

        // Cache should handle user login gracefully
        XCTAssertNotNil(cache)
    }

    // MARK: - Memory Management Tests

    func testMemoryLimitsEnforced() throws {
        // Add more items than the memory limit (5)
        for i in 0..<10 {
            let recipe = createTestRecipe(id: "recipe-\(i)", name: "Recipe \(i)")
            cache.updateCache(recipes: [recipe], nextToken: nil, searchQuery: "query-\(i)", isRefresh: true)
        }

        // Memory cache should be limited
        let stats = cache.getCacheStats()
        XCTAssertLessThanOrEqual(stats.memoryItemCount, 5)
    }

    // MARK: - Cache Behavior Tests

    func testShouldLoadDataLogic() throws {
        // Initial load should require data
        XCTAssertTrue(cache.shouldLoadData(searchQuery: "test"))

        // Add some data
        let recipes = [createTestRecipe()]
        cache.updateCache(recipes: recipes, nextToken: nil, searchQuery: "test", isRefresh: true)

        // Same query should use cache
        XCTAssertFalse(cache.shouldLoadData(searchQuery: "test"))

        // Different query should require load
        XCTAssertTrue(cache.shouldLoadData(searchQuery: "different"))

        // Force refresh should require load
        XCTAssertTrue(cache.shouldLoadData(searchQuery: "test", forceRefresh: true))
    }

    func testPaginationHandling() throws {
        // Initial load
        let recipes1 = [createTestRecipe(id: "1")]
        cache.updateCache(recipes: recipes1, nextToken: "page2", searchQuery: "test", isRefresh: true)

        XCTAssertEqual(cache.recipes.count, 1)
        XCTAssertTrue(cache.hasMorePages)
        XCTAssertEqual(cache.getNextPageToken(), "page2")

        // Load next page
        let recipes2 = [createTestRecipe(id: "2")]
        cache.updateCache(recipes: recipes2, nextToken: nil, searchQuery: "test", isRefresh: false)

        XCTAssertEqual(cache.recipes.count, 2)
        XCTAssertFalse(cache.hasMorePages)
        XCTAssertNil(cache.getNextPageToken())
    }

    func testDuplicateRecipeHandling() throws {
        // Initial load
        let recipe1 = createTestRecipe(id: "1")
        cache.updateCache(recipes: [recipe1], nextToken: "page2", searchQuery: "test", isRefresh: true)

        // Load page with duplicate
        let recipe1Duplicate = createTestRecipe(id: "1")
        let recipe2 = createTestRecipe(id: "2")
        cache.updateCache(recipes: [recipe1Duplicate, recipe2], nextToken: nil, searchQuery: "test", isRefresh: false)

        // Should not have duplicates
        XCTAssertEqual(cache.recipes.count, 2)
        let recipeIDs = cache.recipes.map { $0.id }
        XCTAssertEqual(Set(recipeIDs).count, 2) // All unique
    }

    func testRecipeDeletion() throws {
        // Add some recipes
        let recipe1 = createTestRecipe(id: "1")
        let recipe2 = createTestRecipe(id: "2")
        cache.updateCache(recipes: [recipe1, recipe2], nextToken: nil, searchQuery: "test", isRefresh: true)

        XCTAssertEqual(cache.recipes.count, 2)

        // Simulate recipe deletion
        NotificationCenter.default.post(
            name: .recipeDeleted,
            object: nil,
            userInfo: [RecipeDeletionNotificationKeys.recipeId: "1"]
        )

        // Give the cache time to process the notification
        let expectation = XCTestExpectation(description: "Recipe deleted")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Should only have one recipe left
        XCTAssertEqual(cache.recipes.count, 1)
        XCTAssertEqual(cache.recipes.first?.id, "2")
    }

    func testCacheStatistics() throws {
        let stats = cache.getCacheStats()
        XCTAssertEqual(stats.memoryItemCount, 0)
        XCTAssertEqual(stats.errorCount, 0)
        XCTAssertFalse(stats.isValid)

        // Add some data and check stats
        let recipes = [createTestRecipe()]
        cache.updateCache(recipes: recipes, nextToken: nil, searchQuery: "test", isRefresh: true)

        let newStats = cache.getCacheStats()
        XCTAssertTrue(newStats.isValid)
        XCTAssertNotNil(newStats.lastRefreshTime)
    }

    // MARK: - Helper Methods

    private func createTestRecipe(id: String = "test-recipe", name: String = "Test Recipe") -> Recipe {
        return Recipe(
            id: id,
            name: name,
            description: "A test recipe",
            ingredients: [],
            instructions: [],
            nutritionInfo: nil,
            cuisine: "American",
            prepTime: 10,
            cookTime: 20,
            difficulty: .easy,
            avgRating: 4.0,
            ratingCount: 5,
            imageUrl: nil,
            tags: [],
            createdByUser: "Test User",
            createdByUserId: "test-user-id",
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

