import Foundation
// import Alamofire

class UserService {
    private let baseURL = "http://127.0.0.1:8000/api"
    
    func fetchProfile(completion: @escaping (Result<UserProfile, Error>) -> Void) {
        // Temporary mock implementation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let mockProfile = UserProfile(
                id: 1,
                userId: 1,
                dietaryRestrictions: ["Vegetarian"],
                allergies: ["Nuts"],
                preferredCuisines: ["Italian", "Asian"],
                calorieGoal: 2000,
                activityLevel: "Moderate",
                createdAt: "",
                updatedAt: ""
            )
            completion(.success(mockProfile))
        }
    }
    
    func updateProfile(_ profile: UserProfile, completion: @escaping (Result<UserProfile, Error>) -> Void) {
        // Temporary mock implementation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(.success(profile))
        }
    }
}