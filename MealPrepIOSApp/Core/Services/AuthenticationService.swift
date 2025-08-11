//
//  AuthenticationService.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//  Enhanced with structured logging and comprehensive error handling.
//

import Foundation

// MARK: - Authentication Service

/// Handles user authentication operations including login, registration, and logout
/// Integrates with NetworkManager for secure token management and API communication
class AuthenticationService {
    private let networkManager = NetworkManager.shared

    // MARK: - Authentication Methods

    /// Authenticate user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: AuthResponse containing access and refresh tokens
    /// - Throws: NetworkError for authentication failures
    func login(email: String, password: String) async throws -> AuthResponse {
        AppLogger.info("Attempting user login for: \(email)", category: .authentication)
        
        let loginRequest = LoginRequest(email: email, password: password)

        do {
            let response: AuthResponse = try await networkManager.post(
                "/auth/login/",
                body: loginRequest,
                responseType: AuthResponse.self,
                requiresAuth: false
            )

            // Store tokens in NetworkManager
            await MainActor.run {
                networkManager.setTokens(accessToken: response.access, refreshToken: response.refresh)
            }
            
            AppLogger.info("User login successful for: \(email)", category: .authentication)
            return response
        } catch {
            AppLogger.error("Login failed for \(email): \(error.localizedDescription)", category: .authentication)
            throw error
        }
    }

    /// Register new user account
    /// - Parameter userData: User registration information
    /// - Returns: AuthResponse containing access and refresh tokens
    /// - Throws: NetworkError for registration failures
    func register(userData: RegisterRequest) async throws -> AuthResponse {
        AppLogger.info("Attempting user registration for: \(userData.email)", category: .authentication)
        
        do {
            let response: AuthResponse = try await networkManager.post(
                "/auth/register/",
                body: userData,
                responseType: AuthResponse.self,
                requiresAuth: false
            )

            // Store tokens in NetworkManager
            await MainActor.run {
                networkManager.setTokens(accessToken: response.access, refreshToken: response.refresh)
            }
            
            AppLogger.info("User registration successful for: \(userData.email)", category: .authentication)
            return response
        } catch {
            AppLogger.error("Registration failed for \(userData.email): \(error.localizedDescription)", category: .authentication)
            throw error
        }
    }

    /// Logout user
    func logout() async throws {
        // Call logout endpoint to invalidate refresh token on server
        do {
            try await networkManager.post(
                "/auth/logout/",
                body: EmptyRequest(),
                responseType: EmptyResponse.self,
                requiresAuth: true
            )
        } catch {
            // Continue with local logout even if server call fails
            AppLogger.warning("Server logout failed: \(error.localizedDescription)", category: .authentication)
        }

        // Clear local tokens
        await MainActor.run {
            networkManager.clearTokens()
        }
    }

    /// Get current user information
    func getCurrentUser() async throws -> User {
        return try await networkManager.get(
            "/auth/me/",
            responseType: User.self,
            requiresAuth: true
        )
    }

    /// Update user profile
    func updateProfile(updates: UserProfileUpdateRequest) async throws -> User {
        return try await networkManager.patch(
            "/auth/profile/",
            body: updates,
            responseType: User.self,
            requiresAuth: true
        )
    }

    /// Change password
    func changePassword(currentPassword: String, newPassword: String) async throws {
        let request = ChangePasswordRequest(
            currentPassword: currentPassword,
            newPassword: newPassword,
            newPasswordConfirm: newPassword
        )

        let _: EmptyResponse = try await networkManager.post(
            "/auth/change-password/",
            body: request,
            responseType: EmptyResponse.self,
            requiresAuth: true
        )
    }

    /// Request password reset
    func requestPasswordReset(email: String) async throws {
        let request = PasswordResetRequest(email: email)

        let _: EmptyResponse = try await networkManager.post(
            "/auth/password-reset/",
            body: request,
            responseType: EmptyResponse.self,
            requiresAuth: false
        )
    }

    /// Confirm password reset
    func confirmPasswordReset(token: String, newPassword: String) async throws {
        let request = PasswordResetConfirmRequest(
            token: token,
            newPassword: newPassword,
            newPasswordConfirm: newPassword
        )

        let _: EmptyResponse = try await networkManager.post(
            "/auth/password-reset-confirm/",
            body: request,
            responseType: EmptyResponse.self,
            requiresAuth: false
        )
    }

    /// Refresh authentication token
    func refreshToken() async throws -> TokenRefreshResponse {
        // This is handled automatically by NetworkManager
        // This method is for manual refresh if needed
        try await networkManager.refreshTokenIfNeeded()
        return TokenRefreshResponse(access: "refreshed") // Placeholder
    }

    /// Check if user is authenticated
    @MainActor
    var isAuthenticated: Bool {
        return networkManager.isAuthenticated
    }
}

// MARK: - Additional Request Models
private struct EmptyRequest: Codable {
    init() {}
}

private struct ChangePasswordRequest: Codable {
    let currentPassword: String
    let newPassword: String
    let newPasswordConfirm: String

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case newPassword = "new_password"
        case newPasswordConfirm = "new_password_confirm"
    }
}

private struct PasswordResetRequest: Codable {
    let email: String
}

private struct PasswordResetConfirmRequest: Codable {
    let token: String
    let newPassword: String
    let newPasswordConfirm: String

    enum CodingKeys: String, CodingKey {
        case token
        case newPassword = "new_password"
        case newPasswordConfirm = "new_password_confirm"
    }
}