//
//  FavoritesStore.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/20/25.
//

import SwiftUI
import Combine

@MainActor
class FavoritesStore: ObservableObject {
    // MARK: - Published Properties
    @Published var favorites: [Favorite] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var searchQuery = ""
    @Published var filters = FavoriteFilters()
    @Published var selectedRating: Int?
    @Published var selectedCuisine: String?
    @Published var selectedDifficulty: Difficulty?
    @Published var sortOrder: FavoriteOrdering = .addedAtDesc
    
    // Pagination
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var hasMorePages = false
    @Published var totalCount = 0
    
    // UI State
    @Published var isAddingToFavorites = false
    @Published var isRemovingFromFavorites = false
    @Published var isUpdatingFavorite = false
    
    private let favoritesService = FavoritesService()
    private var cancellables = Set<AnyCancellable>()
    private let pageSize = 20
    
    // Cache for favorite status checks
    private var favoriteStatusCache: [String: Bool] = [:]
    
    init() {
        setupSearchDebouncing()
        setupNotificationObservers()
    }
    
    // MARK: - Setup Methods
    
    private func setupNotificationObservers() {
        // Listen for recipe deletion notifications
        NotificationCenter.default.addObserver(
            forName: .recipeDeleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let recipeId = notification.userInfo?[RecipeDeletionNotificationKeys.recipeId] as? String {
                Task { @MainActor in
                    self?.removeDeletedRecipeFromFavorites(recipeId: recipeId)
                }
            }
        }
        
        // Listen for user logout to clear data
        NotificationCenter.default.addObserver(
            forName: .userLoggedOut,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.clearAllData()
            }
        }
    }
    
    private func setupSearchDebouncing() {
        // Debounce search queries to avoid too many API calls
        $searchQuery
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task {
                    await self?.searchFavorites()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Favorites Loading
    
    func loadFavorites(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            favorites = []
            favoriteStatusCache.removeAll()
        }
        
        isLoading = !refresh && favorites.isEmpty
        isLoadingMore = !favorites.isEmpty
        
        do {
            let response = try await favoritesService.getFavorites(
                page: currentPage,
                pageSize: pageSize,
                filters: buildCurrentFilters()
            )
            
            if refresh || currentPage == 1 {
                favorites = response.results
            } else {
                favorites.append(contentsOf: response.results)
            }
            
            totalPages = response.totalPages
            totalCount = response.count
            hasMorePages = response.next != nil
            
            // Update cache
            for favorite in response.results {
                favoriteStatusCache[favorite.recipe.id] = true
            }
            
        } catch {
        }
        
        isLoading = false
        isLoadingMore = false
    }
    
    func loadMoreFavorites() async {
        guard hasMorePages && !isLoadingMore else { return }
        
        currentPage += 1
        await loadFavorites()
    }
    
    func refreshFavorites() async {
        await loadFavorites(refresh: true)
    }
    
    // MARK: - Search and Filters
    
    func searchFavorites() async {
        currentPage = 1
        await loadFavorites(refresh: true)
    }
    
    func clearSearch() async {
        searchQuery = ""
        await refreshFavorites()
    }
    
    func applyFilters() async {
        currentPage = 1
        await loadFavorites(refresh: true)
    }
    
    func clearFilters() async {
        filters = FavoriteFilters()
        selectedRating = nil
        selectedCuisine = nil
        selectedDifficulty = nil
        sortOrder = .addedAtDesc
        await refreshFavorites()
    }
    
    private func buildCurrentFilters() -> FavoriteFilters {
        return FavoriteFilters(
            search: searchQuery.isEmpty ? nil : searchQuery,
            personalRating: selectedRating,
            personalRatingMin: filters.personalRatingMin,
            personalRatingMax: filters.personalRatingMax,
            recipeCuisine: selectedCuisine,
            recipeDifficulty: selectedDifficulty,
            addedAtMin: filters.addedAtMin,
            addedAtMax: filters.addedAtMax,
            ordering: sortOrder
        )
    }
    
    // MARK: - Favorite Management
    
    func addToFavorites(recipeId: String, rating: Int? = nil, notes: String? = nil) async -> Bool {
        isAddingToFavorites = true
        
        do {
            let favorite = try await favoritesService.addToFavorites(recipeId: recipeId, rating: rating, notes: notes)
            
            // Add to the beginning of the list
            favorites.insert(favorite, at: 0)
            totalCount += 1
            
            // Update cache
            favoriteStatusCache[recipeId] = true
            
            isAddingToFavorites = false
            return true
        } catch {
            isAddingToFavorites = false
            return false
        }
    }
    
    func removeFromFavorites(recipeId: String) async -> Bool {
        isRemovingFromFavorites = true
        
        do {
            try await favoritesService.removeFromFavorites(recipeId: recipeId)
            
            // Remove from the list
            favorites.removeAll { $0.recipe.id == recipeId }
            totalCount = max(0, totalCount - 1)
            
            // Update cache
            favoriteStatusCache[recipeId] = false
            
            isRemovingFromFavorites = false
            return true
        } catch {
            isRemovingFromFavorites = false
            return false
        }
    }
    
    func updateFavorite(favoriteId: String, rating: Int? = nil, notes: String? = nil) async -> Bool {
        isUpdatingFavorite = true
        
        do {
            let updatedFavorite = try await favoritesService.updateFavorite(favoriteId: favoriteId, rating: rating, notes: notes)
            
            // Update in the list
            if let index = favorites.firstIndex(where: { $0.id == favoriteId }) {
                favorites[index] = updatedFavorite
            }
            
            isUpdatingFavorite = false
            return true
        } catch {
            isUpdatingFavorite = false
            return false
        }
    }
    
    func toggleFavorite(recipeId: String, rating: Int? = nil, notes: String? = nil) async throws -> Bool {
        do {
            let newStatus = try await favoritesService.toggleFavorite(recipeId: recipeId, rating: rating, notes: notes)
            
            if newStatus {
                // Recipe was added to favorites, refresh to get the new favorite
                await refreshFavorites()
            } else {
                // Recipe was removed from favorites
                favorites.removeAll { $0.recipe.id == recipeId }
                totalCount = max(0, totalCount - 1)
            }
            
            // Update cache
            favoriteStatusCache[recipeId] = newStatus
            
            return newStatus
        } catch {
            // Log the error for debugging
            print("Error toggling favorite: \(error)")
            
            // Update the error message
            errorMessage = "Failed to update favorite status: \(error.localizedDescription)"
            
            // Rethrow the error
            throw error
        }
    }
    
    // MARK: - Favorite Status Checking
    
    func checkFavoriteStatus(recipeId: String) async throws -> FavoriteStatus {
        // Check cache first
        if let cachedStatus = favoriteStatusCache[recipeId] {
            if cachedStatus {
                // Find the favorite in our list
                if let favorite = favorites.first(where: { $0.recipe.id == recipeId }) {
                    return FavoriteStatus(isFavorite: true, favorite: favorite)
                }
            } else {
                return FavoriteStatus(isFavorite: false, favorite: nil)
            }
        }
        
        // Fetch from API
        let status = try await favoritesService.checkFavoriteStatus(recipeId: recipeId)
        
        // Update cache
        favoriteStatusCache[recipeId] = status.isFavorite
        
        return status
    }
    
    func isFavorite(recipeId: String) -> Bool {
        return favoriteStatusCache[recipeId] ?? favorites.contains { $0.recipe.id == recipeId }
    }
    
    // MARK: - Convenience Methods
    
    func getFavoritesByRating(_ rating: Int) async {
        selectedRating = rating
        await applyFilters()
    }
    
    func getHighlyRatedFavorites() async {
        filters = FavoriteFilters(personalRatingMin: 4)
        await applyFilters()
    }
    
    func getFavoritesByCuisine(_ cuisine: String) async {
        selectedCuisine = cuisine
        await applyFilters()
    }
    
    func getRecentFavorites() async {
        sortOrder = .addedAtDesc
        await applyFilters()
    }
    
    func getAllFavorites() async {
        do {
            let allFavorites = try await favoritesService.getAllFavorites()
            favorites = allFavorites
            totalCount = allFavorites.count
            
            // Update cache
            for favorite in allFavorites {
                favoriteStatusCache[favorite.recipe.id] = true
            }
        } catch {
        }
    }
    
    // MARK: - Batch Operations
    
    func addMultipleToFavorites(_ recipeIds: [String]) async -> [Result<Favorite, Error>] {
        do {
            let results = try await favoritesService.addMultipleToFavorites(recipeIds)
            
            // Update local state for successful additions
            for (index, result) in results.enumerated() {
                if case .success(let favorite) = result {
                    favorites.insert(favorite, at: 0)
                    favoriteStatusCache[recipeIds[index]] = true
                }
            }
            
            totalCount = favorites.count
            return results
        } catch {
            return recipeIds.map { _ in .failure(error) }
        }
    }
    
    // MARK: - Computed Properties
    
    var isEmpty: Bool {
        favorites.isEmpty && !isLoading
    }
    
    var isSearching: Bool {
        !searchQuery.isEmpty
    }
    
    var hasFilters: Bool {
        selectedRating != nil ||
        selectedCuisine != nil ||
        selectedDifficulty != nil ||
        filters.personalRatingMin != nil ||
        filters.personalRatingMax != nil ||
        filters.addedAtMin != nil ||
        filters.addedAtMax != nil ||
        sortOrder != .addedAtDesc
    }
    
    var statusText: String {
        if isLoading {
            return "Loading favorites..."
        } else if isEmpty && isSearching {
            return "No favorites found for '\(searchQuery)'"
        } else if isEmpty && hasFilters {
            return "No favorites match your filters"
        } else if isEmpty {
            return "No favorites yet"
        } else {
            return "\(totalCount) favorite\(totalCount == 1 ? "" : "s")"
        }
    }
    
    // MARK: - Recipe Cleanup
    
    /// Remove a deleted recipe from favorites
    private func removeDeletedRecipeFromFavorites(recipeId: String) {
        print("🧹 [FavoritesStore] Cleaning up deleted recipe: \(recipeId)")
        
        let originalCount = favorites.count
        
        // Remove from favorites list
        favorites.removeAll { $0.recipe.id == recipeId }
        
        // Remove from cache
        favoriteStatusCache.removeValue(forKey: recipeId)
        
        // Update total count
        let removedCount = originalCount - favorites.count
        if removedCount > 0 {
            totalCount = max(0, totalCount - removedCount)
            print("✅ [FavoritesStore] Removed \(removedCount) favorite(s) for deleted recipe")
        } else {
            print("📝 [FavoritesStore] No favorites found for deleted recipe")
        }
    }
    
    /// Clear all data when user logs out
    private func clearAllData() {
        favorites = []
        favoriteStatusCache.removeAll()
        searchQuery = ""
        filters = FavoriteFilters()
        selectedRating = nil
        selectedCuisine = nil
        selectedDifficulty = nil
        sortOrder = .addedAtDesc
        currentPage = 1
        totalPages = 1
        hasMorePages = false
        totalCount = 0
        errorMessage = nil
        
        print("🧹 [FavoritesStore] Cleared all data after user logout")
    }
    
    /// Cleanup method for deinit
    deinit {
        // Remove observers to prevent memory leaks
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
    }
    
    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}