//
//  RecipeStoreTests.swift
//  MealPrepIOSAppTests
//
//  Created by AI Assistant on 7/21/25.
//

import Testing
import Foundation
@testable import MealPrepIOSApp

@MainActor
struct RecipeStoreTests {
    
    @Test("Recipe store initializes correctly")
    func testInitialization() async throws {
        let store = RecipeStore()
        
        #expect(store.recipes.isEmpty)
        #expect(store.currentRecipe == nil)
        #expect(store.isLoading == false)
        #expect(store.searchQuery.isEmpty)
        #expect(store.currentPage == 1)
    }
    
    @Test("Search query updates trigger debounced search")
    func testSearchDebouncing() async throws {
        let store = RecipeStore()
        
        // Test that search query can be set
        store.searchQuery = "test"
        #expect(store.searchQuery == "test")
        #expect(store.isSearching == true)
        
        // Clear search
        store.searchQuery = ""
        #expect(store.isEmpty == true)
        #expect(store.isSearching == false)
    }
    
    @Test("Filter state management")
    func testFilterState() async throws {
        let store = RecipeStore()
        
        // Initially no filters
        #expect(store.hasFilters == false)
        
        // Add a cuisine filter
        store.selectedCuisine = "Italian"
        #expect(store.hasFilters == true)
        
        // Add difficulty filter
        store.selectedDifficulty = .easy
        #expect(store.hasFilters == true)
        
        // Clear filters should reset everything
        await store.clearFilters()
        #expect(store.hasFilters == false)
        #expect(store.selectedCuisine == nil)
        #expect(store.selectedDifficulty == nil)
    }
    
    @Test("Status text updates correctly")
    func testStatusText() async throws {
        let store = RecipeStore()
        
        // Empty state
        #expect(store.statusText == "No recipes available")
        
        // Loading state
        store.isLoading = true
        #expect(store.statusText == "Loading recipes...")
        
        // Reset
        store.isLoading = false
        
        // Search with no results
        store.searchQuery = "nonexistent"
        #expect(store.statusText == "No recipes found for 'nonexistent'")
    }
}