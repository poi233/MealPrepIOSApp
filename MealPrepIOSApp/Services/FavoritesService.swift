//
//  FavoritesService.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import Foundation

// MARK: - Favorites Service
@MainActor
class FavoritesService {
    private let networkManager = NetworkManager.shared
    
    // MARK: - Favorites Management
    
    /// Get user's favorite recipes with optional filters
    func getFavorites(page: Int = 1, pageSize: Int = 20, filters: FavoriteFilters? = nil) async throws -> PaginatedResponse<Favorite> {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]
        
        // Add filter parameters
        if let filters = filters {
            if let search = filters.search, !search.isEmpty {
                queryItems.append(URLQueryItem(name: "search", value: search))
            }
            if let personalRating = filters.personalRating {
                queryItems.append(URLQueryItem(name: "personal_rating", value: String(personalRating)))
            }
            if let personalRatingMin = filters.personalRatingMin {
                queryItems.append(URLQueryItem(name: "personal_rating__gte", value: String(personalRatingMin)))
            }
            if let personalRatingMax = filters.personalRatingMax {
                queryItems.append(URLQueryItem(name: "personal_rating__lte", value: String(personalRatingMax)))
            }
            if let recipeCuisine = filters.recipeCuisine {
                queryItems.append(URLQueryItem(name: "recipe__cuisine", value: recipeCuisine))
            }
            if let recipeDifficulty = filters.recipeDifficulty {
                queryItems.append(URLQueryItem(name: "recipe__difficulty", value: recipeDifficulty.rawValue))
            }
            if let ordering = filters.ordering {
                queryItems.append(URLQueryItem(name: "ordering", value: ordering.rawValue))
            }
            
            // Date filters
            if let addedAtMin = filters.addedAtMin {
                let formatter = ISO8601DateFormatter()
                queryItems.append(URLQueryItem(name: "added_at__gte", value: formatter.string(from: addedAtMin)))
            }
            if let addedAtMax = filters.addedAtMax {
                let formatter = ISO8601DateFormatter()
                queryItems.append(URLQueryItem(name: "added_at__lte", value: formatter.string(from: addedAtMax)))
            }
        }
        
        return try await networkManager.get(
            "/favorites/favorites/",
            queryItems: queryItems,
            responseType: PaginatedResponse<Favorite>.self,
            requiresAuth: true
        )
    }
    
    /// Add a recipe to favorites
    func addToFavorites(recipeId: String, rating: Int? = nil, notes: String? = nil) async throws -> Favorite {
        // Validate rating if provided (must be between 1-5 according to documentation)
        if let rating = rating, (rating < 1 || rating > 5) {
            throw NetworkError.serverError(400, "Rating must be between 1 and 5")
        }
        
        let request = AddToFavoritesRequest(personalRating: rating, personalNotes: notes)
        
        return try await networkManager.post(
            "/favorites/recipe/\(recipeId)/",
            body: request,
            responseType: Favorite.self,
            requiresAuth: true
        )
    }
    
    /// Remove a recipe from favorites
    func removeFromFavorites(recipeId: String) async throws {
        do {
            try await networkManager.delete(
                "/favorites/recipe/\(recipeId)/",
                requiresAuth: true
            )
        } catch let error as NetworkError {
            // Handle 404 errors gracefully - if the recipe is not in favorites, consider it a success
            if case .serverError(404, _) = error {
                // Recipe was not in favorites, which is fine - it's already in the state we want
                return
            }
            throw error
        }
    }
    
    /// Check if a recipe is in favorites
    func checkFavoriteStatus(recipeId: String) async throws -> FavoriteStatus {
        return try await networkManager.get(
            "/favorites/recipe/\(recipeId)/",
            responseType: FavoriteStatus.self,
            requiresAuth: true
        )
    }
    
    /// Update favorite rating and notes
    func updateFavorite(favoriteId: String, rating: Int? = nil, notes: String? = nil) async throws -> Favorite {
        // Validate rating if provided (must be between 1-5 according to documentation)
        if let rating = rating, (rating < 1 || rating > 5) {
            throw NetworkError.serverError(400, "Rating must be between 1 and 5")
        }
        
        let request = UpdateFavoriteRequest(personalRating: rating, personalNotes: notes)
        
        return try await networkManager.put(
            "/favorites/favorites/\(favoriteId)/",
            body: request,
            responseType: Favorite.self,
            requiresAuth: true
        )
    }
    
    // MARK: - Convenience Methods
    
    /// Get all favorites (without pagination)
    func getAllFavorites() async throws -> [Favorite] {
        var allFavorites: [Favorite] = []
        var currentPage = 1
        var hasMore = true
        
        while hasMore {
            let response = try await getFavorites(page: currentPage, pageSize: 50)
            allFavorites.append(contentsOf: response.results)
            
            hasMore = response.next != nil
            currentPage += 1
        }
        
        return allFavorites
    }
    
    /// Search favorites
    func searchFavorites(query: String, page: Int = 1) async throws -> PaginatedResponse<Favorite> {
        let filters = FavoriteFilters(search: query)
        return try await getFavorites(page: page, filters: filters)
    }
    
    /// Get favorites by rating
    func getFavoritesByRating(_ rating: Int, page: Int = 1) async throws -> PaginatedResponse<Favorite> {
        let filters = FavoriteFilters(personalRating: rating)
        return try await getFavorites(page: page, filters: filters)
    }
    
    /// Get highly rated favorites (4+ stars)
    func getHighlyRatedFavorites(page: Int = 1) async throws -> PaginatedResponse<Favorite> {
        let filters = FavoriteFilters(personalRatingMin: 4)
        return try await getFavorites(page: page, filters: filters)
    }
    
    /// Get favorites by cuisine
    func getFavoritesByCuisine(_ cuisine: String, page: Int = 1) async throws -> PaginatedResponse<Favorite> {
        let filters = FavoriteFilters(recipeCuisine: cuisine)
        return try await getFavorites(page: page, filters: filters)
    }
    
    /// Get recently added favorites
    func getRecentFavorites(page: Int = 1) async throws -> PaginatedResponse<Favorite> {
        let filters = FavoriteFilters(ordering: .addedAtDesc)
        return try await getFavorites(page: page, filters: filters)
    }
    
    /// Toggle favorite status (add if not favorite, remove if favorite)
    func toggleFavorite(recipeId: String, rating: Int? = nil, notes: String? = nil) async throws -> Bool {
        // Debug log
        print("Toggling favorite for recipe \(recipeId) with rating: \(String(describing: rating)), notes: \(String(describing: notes))")
        
        // Validate rating if provided (must be between 1-5 according to documentation)
        if let rating = rating, (rating < 1 || rating > 5) {
            throw NetworkError.serverError(400, "Rating must be between 1 and 5")
        }
        
        do {
            let status = try await checkFavoriteStatus(recipeId: recipeId)
            
            if status.isFavorite {
                // Remove from favorites
                try await removeFromFavorites(recipeId: recipeId)
                return false
            } else {
                // Add to favorites
                _ = try await addToFavorites(recipeId: recipeId, rating: rating, notes: notes)
                return true
            }
        } catch let error as NetworkError {
            // Handle specific network errors
            switch error {
            case .serverError(404, _):
                // If we get a 404 when checking status, it means the recipe is not in favorites
                // So we should add it to favorites
                _ = try await addToFavorites(recipeId: recipeId, rating: rating, notes: notes)
                return true
            default:
                // For other errors, rethrow
                throw error
            }
        } catch {
            // For any other errors, try to add first
            do {
                _ = try await addToFavorites(recipeId: recipeId, rating: rating, notes: notes)
                return true
            } catch let addError as NetworkError {
                // If adding fails with a 400 error, it might already be a favorite, so try to remove
                if case .serverError(400, _) = addError {
                    do {
                        try await removeFromFavorites(recipeId: recipeId)
                        return false
                    } catch {
                        // If removing also fails, rethrow the original error
                        throw error
                    }
                } else {
                    throw addError
                }
            }
        }
    }
    
    /// Batch add multiple recipes to favorites
    func addMultipleToFavorites(_ recipeIds: [String]) async throws -> [Result<Favorite, Error>] {
        var results: [Result<Favorite, Error>] = []
        
        // Process in parallel with limited concurrency
        await withTaskGroup(of: (Int, Result<Favorite, Error>).self) { group in
            for (index, recipeId) in recipeIds.enumerated() {
                group.addTask {
                    do {
                        let favorite = try await self.addToFavorites(recipeId: recipeId)
                        return (index, .success(favorite))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            
            // Collect results in order
            var tempResults: [(Int, Result<Favorite, Error>)] = []
            for await result in group {
                tempResults.append(result)
            }
            
            // Sort by index to maintain order
            tempResults.sort { $0.0 < $1.0 }
            results = tempResults.map { $0.1 }
        }
        
        return results
    }
}
