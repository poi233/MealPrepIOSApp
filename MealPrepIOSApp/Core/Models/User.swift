//
//  User.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import Foundation

// MARK: - User Model
struct User: Codable, Identifiable {
    let id: String
    let username: String
    let email: String
    let displayName: String?
    let dietaryPreferences: DietaryPreferences?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case displayName = "display_name"
        case dietaryPreferences = "dietary_preferences"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Regular initializer for internal use
    init(id: String, username: String, email: String, displayName: String? = nil, dietaryPreferences: DietaryPreferences? = nil, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.username = username
        self.email = email
        self.displayName = displayName
        self.dietaryPreferences = dietaryPreferences
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle id as either String or Int
        if let idString = try? container.decode(String.self, forKey: .id) {
            id = idString
        } else if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = String(idInt)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "ID must be either String or Int")
        }

        username = try container.decode(String.self, forKey: .username)
        email = try container.decode(String.self, forKey: .email)

        // Handle display_name - convert empty string to nil
        let displayNameString = try container.decodeIfPresent(String.self, forKey: .displayName)
        displayName = displayNameString?.isEmpty == true ? nil : displayNameString

        dietaryPreferences = try container.decodeIfPresent(DietaryPreferences.self, forKey: .dietaryPreferences)

        // Handle dates with flexible parsing
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    var fullDisplayName: String {
        return displayName ?? username
    }
}

// MARK: - Authentication Models
struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let username: String
    let email: String
    let password: String
    let passwordConfirm: String
    let displayName: String?
    let dietaryPreferences: DietaryPreferences?

    enum CodingKeys: String, CodingKey {
        case username
        case email
        case password
        case passwordConfirm = "password_confirm"
        case displayName = "display_name"
        case dietaryPreferences = "dietary_preferences"
    }
}

struct AuthResponse: Codable {
    let user: User
    let access: String
    let refresh: String
}

struct TokenRefreshRequest: Codable {
    let refresh: String
}

// MARK: - User Profile Update Models
struct UserProfileUpdateRequest: Codable {
    let displayName: String?
    let dietaryPreferences: DietaryPreferences?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case dietaryPreferences = "dietary_preferences"
    }
}

// MARK: - Dietary Preferences
enum DietType: String, CaseIterable, Codable {
    case vegetarian = "vegetarian"
    case vegan = "vegan"
    case keto = "keto"
    case paleo = "paleo"
    case mediterranean = "mediterranean"

    var displayName: String {
        switch self {
        case .vegetarian:
            return "Vegetarian"
        case .vegan:
            return "Vegan"
        case .keto:
            return "Keto"
        case .paleo:
            return "Paleo"
        case .mediterranean:
            return "Mediterranean"
        }
    }
}

struct DietaryPreferences: Codable {
    let dietType: String?
    let allergies: [String]?
    let dislikes: [String]?
    let calorieTarget: Int?

    enum CodingKeys: String, CodingKey {
        case dietType = "diet_type"
        case allergies
        case dislikes
        case calorieTarget = "calorie_target"
    }

    init(dietType: String? = nil, allergies: [String]? = nil, dislikes: [String]? = nil, calorieTarget: Int? = nil) {
        self.dietType = dietType
        self.allergies = allergies
        self.dislikes = dislikes
        self.calorieTarget = calorieTarget
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dietType = try container.decodeIfPresent(String.self, forKey: .dietType)
        allergies = try container.decodeIfPresent([String].self, forKey: .allergies)
        dislikes = try container.decodeIfPresent([String].self, forKey: .dislikes)
        calorieTarget = try container.decodeIfPresent(Int.self, forKey: .calorieTarget)
    }
}