//
//  AuthStore.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/20/25.
//

import SwiftUI
import Combine

@MainActor
class AuthStore: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var sessionError: String?
    @Published var sessionWillExpireSoon = false
    
    private let authService = AuthenticationService()
    private let networkManager = NetworkManager.shared
    private let userCacheManager = UserCacheManager()
    private let errorHandler = ErrorHandler.shared
    private var cancellables = Set<AnyCancellable>()
    private var sessionCheckTimer: Timer?
    private var sessionRefreshTimer: Timer?
    
    init() {
        // Observe network manager authentication state
        networkManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuth in
                self?.isAuthenticated = isAuth
                if !isAuth {
                    self?.currentUser = nil
                }
            }
            .store(in: &cancellables)
        
        // Don't call checkAuthenticationStatus() immediately in init
        // This will be called from the App when it's ready
    }
    
    // MARK: - Initialization
    
    func initialize() {
        checkAuthenticationStatus()
        startSessionMonitoring()
    }
    
    // MARK: - Authentication Status
    
    func checkAuthenticationStatus() {
        Task {
            // First try to load from cache
            await loadCurrentUserFromCache()
            
            // Then update from server if authenticated
            if networkManager.isAuthenticated {
                await loadCurrentUser()
            }
        }
    }
    
    private func loadCurrentUserFromCache() async {
        do {
            if let cachedUser = try await userCacheManager.getCurrentUser() {
                await MainActor.run {
                    self.currentUser = cachedUser
                    self.isAuthenticated = true
                }
            }
        } catch {
            print("Failed to load cached user: \(error)")
        }
    }
    
    private func loadCurrentUser() async {
        do {
            let user = try await authService.getCurrentUser()
            self.currentUser = user
            self.isAuthenticated = true
            
            // Cache the user
            try await userCacheManager.saveCurrentUser(user)
        } catch {
            print("Failed to load current user: \(error.localizedDescription)")
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }
    
    // MARK: - Authentication Actions
    
    func login(email: String, password: String) async {
        isLoading = true
        
        do {
            let response = try await authService.login(email: email, password: password)
            self.currentUser = response.user
            self.isAuthenticated = true
            
            // Start session monitoring after successful login
            startSessionMonitoring()
        } catch {
            // Handle specific error types more gracefully
            if let networkError = error as? NetworkError {
                switch networkError {
                case .unknownError(let underlyingError):
                    // Check if this is a cancellation error
                    let nsError = underlyingError as NSError
                    if nsError.code == NSURLErrorCancelled {
                        // Don't show cancellation errors to user - they're usually not actionable
                        print("Login request was cancelled")
                    } else {
                        print("Login failed with unknown error: \(underlyingError)")
                    }
                case .networkUnavailable:
                    print("Login failed: No internet connection")
                case .requestTimeout:
                    print("Login failed: Request timed out")
                case .serverError(let code, _):
                    if code == 401 {
                        print("Login failed: Invalid credentials")
                    } else {
                        print("Login failed: Server error \(code)")
                    }
                default:
                    print("Login failed: \(error.localizedDescription)")
                }
            } else {
                print("Login failed: \(error.localizedDescription)")
            }
            
            errorHandler.handle(error, context: "Login")
            self.isAuthenticated = false
            self.currentUser = nil
        }
        
        isLoading = false
        
        // Stop session monitoring on logout
        stopSessionMonitoring()
    }
    
    func register(userData: RegisterData) async {
        isLoading = true
        
        do {
            let registerRequest = RegisterRequest(
                username: userData.username,
                email: userData.email,
                password: userData.password,
                passwordConfirm: userData.password,
                displayName: userData.displayName,
                dietaryPreferences: nil
            )
            
            let response = try await authService.register(userData: registerRequest)
            self.currentUser = response.user
            self.isAuthenticated = true
        } catch {
            self.isAuthenticated = false
            self.currentUser = nil
        }
        
        isLoading = false
    }
    
    func logout() async {
        isLoading = true
        
        do {
            try await authService.logout()
        } catch {
            print("Logout error: \(error.localizedDescription)")
        }
        
        // Clear cache
        do {
            try await userCacheManager.clearCurrentUser()
        } catch {
            print("Failed to clear user cache: \(error)")
        }
        
        // Clear local state regardless of server response
        self.currentUser = nil
        self.isAuthenticated = false
        self.sessionError = nil
        
        isLoading = false
    }
    
    // MARK: - Profile Management
    
    func updateProfile(updates: ProfileUpdates) async -> Bool {
        isLoading = true
        
        do {
            let updateRequest = UserProfileUpdateRequest(
                displayName: updates.displayName,
                dietaryPreferences: updates.dietaryPreferences
            )
            
            let updatedUser = try await authService.updateProfile(updates: updateRequest)
            self.currentUser = updatedUser
            
            isLoading = false
            return true
        } catch {
            isLoading = false
            return false
        }
    }
    
    func changePassword(currentPassword: String, newPassword: String) async -> Bool {
        isLoading = true
        
        do {
            try await authService.changePassword(currentPassword: currentPassword, newPassword: newPassword)
            
            isLoading = false
            return true
        } catch {
            isLoading = false
            return false
        }
    }
    
    func requestPasswordReset(email: String) async -> Bool {
        isLoading = true
        
        do {
            try await authService.requestPasswordReset(email: email)
            
            isLoading = false
            return true
        } catch {
            isLoading = false
            return false
        }
    }
    
    // MARK: - Session Management
    
    func refreshUser() async {
        await loadCurrentUser()
    }
    
    func clearSessionError() {
        sessionError = nil
        sessionWillExpireSoon = false
    }
    
    func handleSessionError(_ error: String) {
        sessionError = error
    }
    
    private func startSessionMonitoring() {
        // Check session status every 5 minutes
        sessionCheckTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkSessionStatus()
            }
        }
        
        // Auto-refresh token every 45 minutes (assuming 1-hour expiry)
        sessionRefreshTimer = Timer.scheduledTimer(withTimeInterval: 2700, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshSessionIfNeeded()
            }
        }
    }
    
    private func stopSessionMonitoring() {
        sessionCheckTimer?.invalidate()
        sessionRefreshTimer?.invalidate()
        sessionCheckTimer = nil
        sessionRefreshTimer = nil
    }
    
    private func checkSessionStatus() async {
        guard isAuthenticated else { return }
        
        do {
            // Try a simple authenticated request to check session validity
            let _ = try await authService.getCurrentUser()
        } catch {
            if let networkError = error as? NetworkError {
                switch networkError {
                case .tokenExpired, .authenticationRequired:
                    await handleSessionExpired()
                case .serverError(401, _):
                    await handleSessionExpired()
                default:
                    break
                }
            }
        }
    }
    
    private func refreshSessionIfNeeded() async {
        guard isAuthenticated else { return }
        
        do {
            try await networkManager.refreshTokenIfNeeded()
            print("Session refreshed successfully")
        } catch {
            print("Failed to refresh session: \(error)")
            if error is NetworkError {
                switch error as! NetworkError {
                case .tokenExpired, .authenticationRequired:
                    await handleSessionExpired()
                default:
                    break
                }
            }
        }
    }
    
    private func handleSessionExpired() async {
        await MainActor.run {
            self.sessionError = "Your session has expired. Please log in again."
            self.isAuthenticated = false
            self.currentUser = nil
        }
        
        // Clear stored tokens
        networkManager.clearTokens()
        
        // Clear cached user data
        do {
            try await userCacheManager.clearCurrentUser()
        } catch {
            print("Failed to clear cached user: \(error)")
        }
        
        // Stop session monitoring
        stopSessionMonitoring()
    }
    
    // MARK: - Validation Helpers
    
    func validateEmail(_ email: String) -> String? {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        
        if email.isEmpty {
            return "Email is required"
        } else if !emailPredicate.evaluate(with: email) {
            return "Please enter a valid email address"
        }
        return nil
    }
    
    func validatePassword(_ password: String) -> String? {
        if password.isEmpty {
            return "Password is required"
        } else if password.count < 8 {
            return "Password must be at least 8 characters"
        }
        return nil
    }
    
    func validateUsername(_ username: String) -> String? {
        if username.isEmpty {
            return "Username is required"
        } else if username.count < 3 {
            return "Username must be at least 3 characters"
        } else if username.count > 30 {
            return "Username must be less than 30 characters"
        }
        return nil
    }
}

// MARK: - Supporting Models

struct RegisterData {
    let username: String
    let email: String
    let password: String
    let displayName: String?
    let dietaryPreferences: DietaryPreferences?
}

struct ProfileUpdates {
    let displayName: String?
    let dietaryPreferences: DietaryPreferences?
    let email: String?
}