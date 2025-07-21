//
//  RecipeStore.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/20/25.
//

import SwiftUI
import Combine

@MainActor
class RecipeStore: ObservableObject {
    // MARK: - Published Properties
    @Published var recipes: [Recipe] = []
    @Published var currentRecipe: Recipe?
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var searchQuery = ""
    @Published var filters = RecipeFilters()
    @Published var selectedCuisine: String?
    @Published var selectedDifficulty: Difficulty?
    @Published var selectedMealType: MealType?
    @Published var showMyRecipesOnly = false
    @Published var isOffline = false
    
    // Pagination
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var hasMorePages = false
    @Published var totalCount = 0
    
    // UI State
    @Published var isCreatingRecipe = false
    @Published var isUpdatingRecipe = false
    @Published var isDeletingRecipe = false
    
    private let recipeService = RecipeService()
    private let cacheManager = RecipeCacheManager()
    private let networkManager = NetworkManager.shared
    private let errorHandler = ErrorHandler.shared
    private var cancellables = Set<AnyCancellable>()
    private let pageSize = 20
    
    init() {
        setupSearchDebouncing()
        setupNetworkObserver()
        loadCachedRecipes()
    }
    
    // MARK: - Setup Methods
    
    private func setupNetworkObserver() {
        networkManager.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isOffline = !isConnected
                if !isConnected {
                    self?.loadCachedRecipes()
                } else {
                    // Sync when back online
                    Task {
                        await self?.syncWithServer()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadCachedRecipes() {
        Task {
            do {
                let cachedRecipes = try await cacheManager.fetch()
                await MainActor.run {
                    self.recipes = cachedRecipes
                    self.totalCount = cachedRecipes.count
                }
            } catch {
                print("Failed to load cached recipes: \(error)")
            }
        }
    }
    
    // MARK: - Search and Filter Setup
    
    private func setupSearchDebouncing() {
        // Debounce search queries to avoid too many API calls
        $searchQuery
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task {
                    await self?.searchRecipes()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Recipe Loading
    
    func loadRecipes(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            recipes = []
        }
        
        isLoading = !refresh && recipes.isEmpty
        isLoadingMore = !recipes.isEmpty
        errorMessage = nil
        
        // If offline, load from cache
        if isOffline {
            await loadFromCache()
            return
        }
        
        do {
            let response = try await recipeService.getRecipes(
                page: currentPage,
                pageSize: pageSize,
                filters: buildCurrentFilters()
            )
            
            if refresh || currentPage == 1 {
                recipes = response.results
            } else {
                // Append only new recipes to avoid duplicates
                let newRecipes = response.results.filter { newRecipe in
                    !recipes.contains { existingRecipe in
                        existingRecipe.id == newRecipe.id
                    }
                }
                recipes.append(contentsOf: newRecipes)
            }
            
            totalPages = response.totalPages
            totalCount = response.count
            hasMorePages = response.next != nil
            
            // Cache the recipes
            try await cacheManager.save(response.results)
            
        } catch {
            errorHandler.handle(error, context: "Loading recipes")
            errorMessage = error.localizedDescription
            // Fallback to cache on error
            await loadFromCache()
        }
        
        isLoading = false
        isLoadingMore = false
    }
    
    private func loadFromCache() async {
        do {
            let cachedRecipes = try await cacheManager.fetch()
            let filteredRecipes = applyLocalFilters(to: cachedRecipes)
            
            self.recipes = filteredRecipes
            self.totalCount = filteredRecipes.count
            self.hasMorePages = false
        } catch {
            print("Failed to load from cache: \(error)")
        }
    }
    
    private func applyLocalFilters(to recipes: [Recipe]) -> [Recipe] {
        var filtered = recipes
        
        // Apply search filter
        if !searchQuery.isEmpty {
            filtered = filtered.filter { recipe in
                recipe.name.localizedCaseInsensitiveContains(searchQuery) ||
                recipe.description.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        // Apply cuisine filter
        if let cuisine = selectedCuisine {
            filtered = filtered.filter { $0.cuisine == cuisine }
        }
        
        // Apply difficulty filter
        if let difficulty = selectedDifficulty {
            filtered = filtered.filter { $0.difficulty == difficulty }
        }
        
        // Apply time filters
        if let maxTime = filters.totalTimeMax {
            filtered = filtered.filter { $0.totalTime <= maxTime }
        }
        
        // Apply rating filter
        if let minRating = filters.avgRatingMin {
            filtered = filtered.filter { $0.avgRating >= minRating }
        }
        
        return filtered
    }
    
    func loadMoreRecipes() async {
        guard hasMorePages && !isLoadingMore else { return }
        
        currentPage += 1
        await loadRecipes()
    }
    
    func refreshRecipes() async {
        await loadRecipes(refresh: true)
    }
    
    // MARK: - Search
    
    func searchRecipes() async {
        currentPage = 1
        await loadRecipes(refresh: true)
    }
    
    func clearSearch() async {
        searchQuery = ""
        await refreshRecipes()
    }
    
    // MARK: - Filters
    
    func applyFilters() async {
        currentPage = 1
        await loadRecipes(refresh: true)
    }
    
    func clearFilters() async {
        filters = RecipeFilters()
        selectedCuisine = nil
        selectedDifficulty = nil
        selectedMealType = nil
        showMyRecipesOnly = false
        await refreshRecipes()
    }
    
    private func buildCurrentFilters() -> RecipeFilters {
        return RecipeFilters(
            search: searchQuery.isEmpty ? nil : searchQuery,
            cuisine: selectedCuisine,
            difficulty: selectedDifficulty,
            prepTimeMax: filters.prepTimeMax,
            cookTimeMax: filters.cookTimeMax,
            totalTimeMax: filters.totalTimeMax,
            avgRatingMin: filters.avgRatingMin,
            tags: filters.tags,
            mealType: selectedMealType,
            myRecipes: showMyRecipesOnly
        )
    }
    
    // MARK: - Individual Recipe Operations
    
    func loadRecipe(id: String) async {
        isLoading = true
        errorMessage = nil
        
        // Try cache first
        do {
            if let cachedRecipe = try await cacheManager.fetchById(id) {
                currentRecipe = cachedRecipe
                isLoading = false
                
                // If online, update in background
                if !isOffline {
                    Task {
                        do {
                            let freshRecipe = try await recipeService.getRecipe(id: id)
                            await MainActor.run {
                                self.currentRecipe = freshRecipe
                            }
                            try await cacheManager.update(freshRecipe)
                        } catch {
                            print("Background refresh failed: \(error)")
                        }
                    }
                }
                return
            }
        } catch {
            print("Cache fetch failed: \(error)")
        }
        
        // If not in cache or offline, try network
        if !isOffline {
            do {
                let recipe = try await recipeService.getRecipe(id: id)
                currentRecipe = recipe
                
                // Cache the recipe
                try await cacheManager.update(recipe)
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            errorMessage = "Recipe not available offline"
        }
        
        isLoading = false
    }
    
    // MARK: - Sync Methods
    
    private func syncWithServer() async {
        // Sync cached recipes with server
        // This is a simplified version - in production, you'd want more sophisticated sync
        await loadRecipes(refresh: true)
    }
    
    func createRecipe(_ recipe: CreateRecipeRequest) async -> Bool {
        isCreatingRecipe = true
        errorMessage = nil
        
        do {
            let newRecipe = try await recipeService.createRecipe(recipe)
            
            // Add to the beginning of the list
            recipes.insert(newRecipe, at: 0)
            totalCount += 1
            
            isCreatingRecipe = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isCreatingRecipe = false
            return false
        }
    }
    
    func updateRecipe(id: String, recipe: CreateRecipeRequest) async -> Bool {
        isUpdatingRecipe = true
        errorMessage = nil
        
        do {
            let updatedRecipe = try await recipeService.updateRecipe(id: id, recipe: recipe)
            
            // Update in the list
            if let index = recipes.firstIndex(where: { $0.id == id }) {
                recipes[index] = updatedRecipe
            }
            
            // Update current recipe if it's the same
            if currentRecipe?.id == id {
                currentRecipe = updatedRecipe
            }
            
            isUpdatingRecipe = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isUpdatingRecipe = false
            return false
        }
    }
    
    func deleteRecipe(id: String) async -> Bool {
        isDeletingRecipe = true
        errorMessage = nil
        
        do {
            try await recipeService.deleteRecipe(id: id)
            
            // Remove from the list
            recipes.removeAll { $0.id == id }
            totalCount = max(0, totalCount - 1)
            
            // Clear current recipe if it's the same
            if currentRecipe?.id == id {
                currentRecipe = nil
            }
            
            isDeletingRecipe = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isDeletingRecipe = false
            return false
        }
    }
    
    // MARK: - Convenience Methods
    
    func getMyRecipes() async {
        showMyRecipesOnly = true
        await refreshRecipes()
    }
    
    func getAllRecipes() async {
        showMyRecipesOnly = false
        await refreshRecipes()
    }
    
    func getRecipesByCuisine(_ cuisine: String) async {
        selectedCuisine = cuisine
        await applyFilters()
    }
    
    func getRecipesByDifficulty(_ difficulty: Difficulty) async {
        selectedDifficulty = difficulty
        await applyFilters()
    }
    
    func getQuickRecipes() async {
        filters = RecipeFilters(totalTimeMax: 30)
        await applyFilters()
    }
    
    func getHighlyRatedRecipes() async {
        filters = RecipeFilters(avgRatingMin: 4.0)
        await applyFilters()
    }
    
    // MARK: - Recipe Discovery
    
    func getRecipesByTags(_ tags: [String]) async {
        filters = RecipeFilters(tags: tags)
        await applyFilters()
    }
    
    func getRecipesByMealType(_ mealType: MealType) async {
        selectedMealType = mealType
        await applyFilters()
    }
    
    // MARK: - Computed Properties
    
    var isEmpty: Bool {
        recipes.isEmpty && !isLoading
    }
    
    var isSearching: Bool {
        !searchQuery.isEmpty
    }
    
    var hasFilters: Bool {
        selectedCuisine != nil ||
        selectedDifficulty != nil ||
        selectedMealType != nil ||
        showMyRecipesOnly ||
        filters.prepTimeMax != nil ||
        filters.cookTimeMax != nil ||
        filters.totalTimeMax != nil ||
        filters.avgRatingMin != nil ||
        !(filters.tags?.isEmpty ?? true)
    }
    
    var statusText: String {
        if isLoading {
            return "Loading recipes..."
        } else if isEmpty && isSearching {
            return "No recipes found for '\(searchQuery)'"
        } else if isEmpty && hasFilters {
            return "No recipes match your filters"
        } else if isEmpty {
            return "No recipes available"
        } else {
            return "\(totalCount) recipe\(totalCount == 1 ? "" : "s")"
        }
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
    }
    
    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}