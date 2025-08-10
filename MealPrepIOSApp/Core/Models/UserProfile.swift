import Foundation

struct UserProfile: Codable, Identifiable {
    let id: Int
    let userId: Int
    let dietaryRestrictions: [String]
    let allergies: [String]
    let preferredCuisines: [String]
    let calorieGoal: Int?
    let activityLevel: String
    let createdAt: String
    let updatedAt: String
}