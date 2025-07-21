#!/usr/bin/env swift

import Foundation

// Test data structures matching the backend response
struct TestFavorite: Codable, Identifiable {
    let id: String
    let userId: String
    let recipe: TestRecipe
    let personalRating: Int?
    let personalNotes: String?
    let addedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case recipe
        case personalRating = "personal_rating"
        case personalNotes = "personal_notes"
        case addedAt = "added_at"
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
        
        userId = try container.decode(String.self, forKey: .userId)
        recipe = try container.decode(TestRecipe.self, forKey: .recipe)
        personalRating = try container.decodeIfPresent(Int.self, forKey: .personalRating)
        personalNotes = try container.decodeIfPresent(String.self, forKey: .personalNotes)
        addedAt = try container.decode(Date.self, forKey: .addedAt)
    }
}

struct TestRecipe: Codable {
    let id: String
    let name: String
    let description: String
}

// Test JSON from the actual backend response (simplified)
let testJSON = """
{
  "id": 24,
  "user_id": "73e6772b-e9b5-4e7f-aad1-21704e1b89fa",
  "recipe": {
    "id": "6cd9f11a-dac0-4ccb-b5f2-d2eabd1b0a40",
    "name": "Test Recipe",
    "description": "Test Description"
  },
  "personal_rating": null,
  "personal_notes": "",
  "added_at": "2025-07-21T03:38:42.188969Z"
}
"""

// Configure date decoder
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .custom { decoder in
    let container = try decoder.singleValueContainer()
    let dateString = try container.decode(String.self)
    
    let formatters: [DateFormatter] = [
        {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            return formatter
        }(),
        {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            return formatter
        }()
    ]
    
    for formatter in formatters {
        if let date = formatter.date(from: dateString) {
            return date
        }
    }
    
    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
}

// Test decoding
do {
    let data = testJSON.data(using: .utf8)!
    let favorite = try decoder.decode(TestFavorite.self, from: data)
    
    print("✅ Successfully decoded favorite!")
    print("ID: \(favorite.id) (type: \(type(of: favorite.id)))")
    print("User ID: \(favorite.userId)")
    print("Recipe Name: \(favorite.recipe.name)")
    print("Personal Rating: \(favorite.personalRating ?? -1)")
    print("Personal Notes: '\(favorite.personalNotes ?? "nil")'")
    print("Added At: \(favorite.addedAt)")
    
} catch {
    print("❌ Failed to decode: \(error)")
    if let decodingError = error as? DecodingError {
        print("Decoding error details: \(decodingError)")
    }
}