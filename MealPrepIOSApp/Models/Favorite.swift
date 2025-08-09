//
//  Favorite.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import Foundation

// MARK: - Favorite Model
struct Favorite: Codable, Identifiable {
    let userId: String
    let recipe: Recipe
    let personalRating: Int?
    let personalNotes: String?
    let addedAt: Date

    // Use recipe ID as the identifier for SwiftUI's Identifiable protocol
    var id: String {
        return recipe.id
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case recipe
        case personalRating = "personal_rating"
        case personalNotes = "personal_notes"
        case addedAt = "added_at"
    }

    // Standard initializer for creating instances programmatically
    init(userId: String, recipe: Recipe, personalRating: Int? = nil, personalNotes: String? = nil, addedAt: Date = Date()) {
        self.userId = userId
        self.recipe = recipe
        self.personalRating = personalRating
        self.personalNotes = personalNotes
        self.addedAt = addedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        userId = try container.decode(String.self, forKey: .userId)
        recipe = try container.decode(Recipe.self, forKey: .recipe)
        personalRating = try container.decodeIfPresent(Int.self, forKey: .personalRating)
        personalNotes = try container.decodeIfPresent(String.self, forKey: .personalNotes)
        addedAt = try container.decode(Date.self, forKey: .addedAt)
    }
}

// MARK: - Add to Favorites Request
struct AddToFavoritesRequest: Codable {
    let personalRating: Int?
    let personalNotes: String?

    enum CodingKeys: String, CodingKey {
        case personalRating = "personal_rating"
        case personalNotes = "personal_notes"
    }

    init(personalRating: Int? = nil, personalNotes: String? = nil) {
        self.personalRating = personalRating
        self.personalNotes = personalNotes
    }

    // Custom encoding to exclude nil values from the JSON
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Only encode non-nil values
        if let rating = personalRating {
            try container.encode(rating, forKey: .personalRating)
        }

        if let notes = personalNotes, !notes.isEmpty {
            try container.encode(notes, forKey: .personalNotes)
        }
    }
}

// MARK: - Update Favorite Request
struct UpdateFavoriteRequest: Codable {
    let personalRating: Int?
    let personalNotes: String?

    enum CodingKeys: String, CodingKey {
        case personalRating = "personal_rating"
        case personalNotes = "personal_notes"
    }

    // Custom encoding to exclude nil values from the JSON
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Only encode non-nil values
        if let rating = personalRating {
            try container.encode(rating, forKey: .personalRating)
        }

        if let notes = personalNotes, !notes.isEmpty {
            try container.encode(notes, forKey: .personalNotes)
        }
    }
}

// MARK: - Favorite Status Response
struct FavoriteStatus: Codable {
    let isFavorite: Bool
    let favorite: Favorite?

    enum CodingKeys: String, CodingKey {
        case isFavorite = "is_favorite"
        case favorite
        case userId = "user_id"
        case recipe
        case personalRating = "personal_rating"
        case personalNotes = "personal_notes"
        case addedAt = "added_at"
    }

    // Standard initializer for creating instances in code
    init(isFavorite: Bool, favorite: Favorite? = nil) {
        self.isFavorite = isFavorite
        self.favorite = favorite
    }

    // Custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(favorite, forKey: .favorite)
    }

    // Custom decoding to handle both response formats:
    // 1. {"is_favorite": false} when not a favorite
    // 2. Full favorite object when it is a favorite
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Check if this is a simple status response
        if let isFavoriteValue = try? container.decode(Bool.self, forKey: .isFavorite) {
            // This is a simple status response: {"is_favorite": false}
            isFavorite = isFavoriteValue
            favorite = try container.decodeIfPresent(Favorite.self, forKey: .favorite)
        } else {
            // This might be a full favorite object response
            // Check if we have the fields that indicate a favorite object
            if container.contains(.userId) && container.contains(.recipe) {
                // This is a full favorite object, decode it and set isFavorite to true
                let favoriteObject = try Favorite(from: decoder)
                isFavorite = true
                favorite = favoriteObject
            } else {
                // Fallback: assume not favorite if we can't determine
                isFavorite = false
                favorite = nil
            }
        }
    }
}

// MARK: - Favorite Status Response (Alternative name for compatibility)
typealias FavoriteStatusResponse = FavoriteStatus

// MARK: - Favorite Filters
struct FavoriteFilters: Codable {
    let search: String?
    let personalRating: Int?
    let personalRatingMin: Int?
    let personalRatingMax: Int?
    let recipeCuisine: String?
    let recipeDifficulty: Difficulty?
    let addedAtMin: Date?
    let addedAtMax: Date?
    let ordering: FavoriteOrdering?

    enum CodingKeys: String, CodingKey {
        case search
        case personalRating = "personal_rating"
        case personalRatingMin = "personal_rating__gte"
        case personalRatingMax = "personal_rating__lte"
        case recipeCuisine = "recipe__cuisine"
        case recipeDifficulty = "recipe__difficulty"
        case addedAtMin = "added_at__gte"
        case addedAtMax = "added_at__lte"
        case ordering
    }

    init(search: String? = nil, personalRating: Int? = nil, personalRatingMin: Int? = nil, personalRatingMax: Int? = nil, recipeCuisine: String? = nil, recipeDifficulty: Difficulty? = nil, addedAtMin: Date? = nil, addedAtMax: Date? = nil, ordering: FavoriteOrdering? = nil) {
        self.search = search
        self.personalRating = personalRating
        self.personalRatingMin = personalRatingMin
        self.personalRatingMax = personalRatingMax
        self.recipeCuisine = recipeCuisine
        self.recipeDifficulty = recipeDifficulty
        self.addedAtMin = addedAtMin
        self.addedAtMax = addedAtMax
        self.ordering = ordering
    }
}

enum FavoriteOrdering: String, CaseIterable, Codable {
    case addedAtDesc = "-added_at"
    case addedAtAsc = "added_at"
    case personalRatingDesc = "-personal_rating"
    case personalRatingAsc = "personal_rating"
    case recipeNameAsc = "recipe__name"
    case recipeNameDesc = "-recipe__name"

    var displayName: String {
        switch self {
        case .addedAtDesc:
            return "Recently Added"
        case .addedAtAsc:
            return "Oldest First"
        case .personalRatingDesc:
            return "Highest Rated"
        case .personalRatingAsc:
            return "Lowest Rated"
        case .recipeNameAsc:
            return "Name A-Z"
        case .recipeNameDesc:
            return "Name Z-A"
        }
    }
}