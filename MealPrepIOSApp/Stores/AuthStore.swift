//
//  AuthStore.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/27/25.
//  Fixed login cache to handle auth expiry vs explicit logout correctly
//

import SwiftUI
import Combine

@MainActor
class AuthStore: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var isInitializing = true // Track initial session loading
    @Published var errorMessage: String?
    @Published var sessionError: String?
    @Published var sessionWillExpireSoon = false

    private let authService = AuthenticationService()
    private let networkManager = NetworkManager.shared
    private let userScopedStorage = UserScopedStorageManager.shared
    // private let userCacheManager = UserCacheManager() // TODO: Implement cache manager

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
                    // Authentication lost - handle session expiry (preserve cache)
                    self?.handleAuthenticationLost()
                }
            }
            .store(in: &cancellables)

        // Don't call checkAuthenticationStatus() immediately in init
        // This will be called from the App when it's ready
    }

    // MARK: - Initialization

    func initialize() {
        // First try to get userId from stored tokens
        if let userID = networkManager.getCurrentUserID() {
            // Set user scope immediately if we have a valid token
            userScopedStorage.setCurrentUser(userID: userID)
            print("🔄 [AuthStore] Set user scope from token on startup: \(userID)")
        } else {
            // Fallback to restore from persistent storage
            if let restoredUserID = userScopedStorage.restoreUserScopeOnStartup() {
                print("🔄 [AuthStore] Restored user scope from persistence on startup: \(restoredUserID)")
            }
        }

        // Then check authentication status
        checkAuthenticationStatus()
        startSessionMonitoring()
    }

    // MARK: - Authentication Status

    /// Handle authentication lost due to session expiry (preserves cache)
    private func handleAuthenticationLost() {
        print("🔒 [AuthStore] Authentication lost - handling session expiry")

        // For auth expiry, we DON'T clear cache - only clear UI state
        // Cache should persist so user can see their data when they log back in

        // Clear current user but keep user scope for cache persistence
        currentUser = nil
        isAuthenticated = false
        isInitializing = false // Ensure we're not stuck in loading state

        // Don't clear user scoped storage - let cache persist
        // Don't send logout notification - this prevents cache clearing

        // Stop session monitoring
        stopSessionMonitoring()

        print("🚪 [AuthStore] Authentication expired - user will need to log in again but cache preserved")
    }

    func checkAuthenticationStatus() {
        Task {
            isInitializing = true

            // First try to load from cache
            await loadCurrentUserFromCache()

            // Then update from server if authenticated
            if networkManager.isAuthenticated {
                await loadCurrentUser()
            }

            // Mark initialization as complete
            await MainActor.run {
                isInitializing = false
            }
        }
    }

    private func loadCurrentUserFromCache() async {
        // TODO: Implement cache loading
        /*
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
        */
    }

    private func loadCurrentUser() async {
        do {
            let user = try await authService.getCurrentUser()
            self.currentUser = user
            self.isAuthenticated = true

            // Set user ID for scoped storage
            userScopedStorage.setCurrentUser(userID: user.id)

            // Send user login notification for cache loading
            NotificationCenter.default.post(name: .userLoggedIn, object: nil, userInfo: ["userID": user.id])

            // TODO: Cache the user (cache not implemented)
            // try await userCacheManager.saveCurrentUser(user)
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

            // Set user ID for scoped storage (persists for app restart)
            userScopedStorage.setCurrentUser(userID: response.user.id)

            // Send user login notification for cache loading
            NotificationCenter.default.post(name: .userLoggedIn, object: nil, userInfo: ["userID": response.user.id])

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

            print("[Login] Error: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
            self.isAuthenticated = false
            self.currentUser = nil
        }

        isLoading = false
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

            // Set user ID for scoped storage (persists for app restart)
            userScopedStorage.setCurrentUser(userID: response.user.id)

            // Send user login notification for cache loading
            NotificationCenter.default.post(name: .userLoggedIn, object: nil, userInfo: ["userID": response.user.id])
        } catch {
            self.isAuthenticated = false
            self.currentUser = nil
        }

        isLoading = false
    }

    /// Explicit logout - clears all cache and persisted data
    func logout() async {
        isLoading = true

        do {
            try await authService.logout()
        } catch {
            print("Logout error: \(error.localizedDescription)")
        }

        // Clear cache completely for explicit logout
        // TODO: Clear cache (cache not implemented)
        // try await userCacheManager.clearCurrentUser()

        // Clear user scoped storage and persisted user ID
        userScopedStorage.clearCurrentUserData()

        // Send user logout notification for cache clearing
        NotificationCenter.default.post(name: .userLoggedOut, object: nil, userInfo: nil)

        // Clear local state regardless of server response
        self.currentUser = nil
        self.isAuthenticated = false
        self.sessionError = nil

        // Stop session monitoring
        stopSessionMonitoring()

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

        // Auto-refresh token every 24 hours (for 30-day token expiry)
        sessionRefreshTimer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
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

    /// Handle session expiry (preserves cache unlike explicit logout)
    private func handleSessionExpired() async {
        await MainActor.run {
            self.sessionError = "Your session has expired. Please log in again."
            self.isAuthenticated = false
            self.currentUser = nil
        }

        // For session expiry, preserve cache but clear tokens
        // Don't clear user scoped storage - cache should persist
        // Don't send logout notification - this prevents cache clearing

        // Clear stored tokens
        networkManager.clearTokens()

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