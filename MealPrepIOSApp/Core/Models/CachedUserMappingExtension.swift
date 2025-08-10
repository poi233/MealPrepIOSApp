//
//  CachedUser+Mapping.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/21/25.
//

import Foundation
import CoreData

extension CachedUser {

    // MARK: - Convert from User to CachedUser
    func fromUser(_ user: User) {
        self.id = user.id
        self.username = user.username
        self.email = user.email
        self.displayName = user.displayName

        // Convert dietary preferences to JSON string
        if let dietaryPreferences = user.dietaryPreferences,
           let dietaryData = try? JSONEncoder().encode(dietaryPreferences),
           let dietaryString = String(data: dietaryData, encoding: .utf8) {
            self.dietaryPreferences = dietaryString
        }

        self.createdAt = user.createdAt
        self.updatedAt = user.updatedAt
    }

    // MARK: - Convert from CachedUser to User
    func toUser() -> User? {
        guard let id = self.id,
              let username = self.username,
              let email = self.email,
              let createdAt = self.createdAt,
              let updatedAt = self.updatedAt else {
            return nil
        }

        // Parse dietary preferences from JSON string
        var dietaryPreferences: DietaryPreferences?
        if let dietaryString = self.dietaryPreferences,
           let dietaryData = dietaryString.data(using: .utf8) {
            dietaryPreferences = try? JSONDecoder().decode(DietaryPreferences.self, from: dietaryData)
        }

        return User(
            id: id,
            username: username,
            email: email,
            displayName: self.displayName,
            dietaryPreferences: dietaryPreferences,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}