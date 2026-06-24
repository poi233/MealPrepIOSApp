import Foundation

class UserService {
    private let authenticationService = AuthenticationService()

    func fetchProfile(completion: @escaping (Result<UserProfile, Error>) -> Void) {
        Task {
            do {
                let user = try await authenticationService.getCurrentUser()
                await MainActor.run {
                    completion(.success(UserProfile(user: user)))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    func updateProfile(_ profile: UserProfile, completion: @escaping (Result<UserProfile, Error>) -> Void) {
        Task {
            do {
                let preferences = DietaryPreferences(
                    dietType: profile.dietaryRestrictions.first,
                    allergies: profile.allergies.isEmpty ? nil : profile.allergies,
                    dislikes: nil,
                    calorieTarget: profile.calorieGoal
                )
                let updatedUser = try await authenticationService.updateProfile(
                    updates: UserProfileUpdateRequest(
                        displayName: nil,
                        dietaryPreferences: preferences
                    )
                )

                await MainActor.run {
                    completion(.success(UserProfile(user: updatedUser)))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
}

private extension UserProfile {
    init(user: User) {
        let numericID = Int(user.id) ?? 0
        let preferences = user.dietaryPreferences

        self.init(
            id: numericID,
            userId: numericID,
            dietaryRestrictions: preferences?.dietType.map { [$0] } ?? [],
            allergies: preferences?.allergies ?? [],
            preferredCuisines: [],
            calorieGoal: preferences?.calorieTarget,
            activityLevel: "",
            createdAt: ISO8601DateFormatter().string(from: user.createdAt),
            updatedAt: ISO8601DateFormatter().string(from: user.updatedAt)
        )
    }
}
