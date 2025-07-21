import SwiftUI

class UserProfileStore: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userService = UserService()
    
    func fetchProfile() {
        isLoading = true
        errorMessage = nil
        
        userService.fetchProfile { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let profile):
                    self?.profile = profile
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func updateProfile(_ profile: UserProfile) {
        isLoading = true
        errorMessage = nil
        
        userService.updateProfile(profile) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let updatedProfile):
                    self?.profile = updatedProfile
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}