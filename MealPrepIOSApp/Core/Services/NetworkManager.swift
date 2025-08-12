//
//  NetworkManager.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import Foundation
import KeychainSwift
import Combine
import Network

// MARK: - API Endpoint Definition
struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let body: Data?
    let queryItems: [URLQueryItem]?
    let requiresAuth: Bool

    init(path: String, method: HTTPMethod = .GET, body: Data? = nil, queryItems: [URLQueryItem]? = nil, requiresAuth: Bool = true) {
        self.path = path
        self.method = method
        self.body = body
        self.queryItems = queryItems
        self.requiresAuth = requiresAuth
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case PATCH = "PATCH"
    case DELETE = "DELETE"
}

// MARK: - Network Errors
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int, String?)
    case authenticationRequired
    case tokenExpired
    case networkUnavailable
    case requestTimeout
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown error")"
        case .authenticationRequired:
            return "Authentication required"
        case .tokenExpired:
            return "Authentication token expired"
        case .networkUnavailable:
            return "Network unavailable"
        case .requestTimeout:
            return "Request timeout"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Network Manager
class NetworkManager: ObservableObject {
    static let shared = NetworkManager()

    private let session: URLSession
    private let baseURL: String
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let keychain: KeychainSwift

    // Token management
    @Published var isAuthenticated = false
    @Published var isConnected = true
    private var accessToken: String?
    private var refreshToken: String?
    private var sessionExpiry: Date?
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "NetworkMonitorQueue")

    private init() {
        // Configure URLSession with custom configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.waitsForConnectivity = true

        self.session = URLSession(configuration: config)

        // Environment-based URL configuration
        self.baseURL = NetworkManager.getBaseURL()

        // Initialize Keychain with app-specific service name
        self.keychain = KeychainSwift()
        self.keychain.synchronizable = false

        // Configure JSON decoder/encoder
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()

        // Configure date formatting with multiple format support
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try different date formats in order of likelihood
            let formatters: [DateFormatter] = [
                // Django default format with microseconds
                {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
                    formatter.timeZone = TimeZone(abbreviation: "UTC")
                    return formatter
                }(),
                // Django format without microseconds
                {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                    formatter.timeZone = TimeZone(abbreviation: "UTC")
                    return formatter
                }(),
                // ISO format with timezone
                {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                    formatter.timeZone = TimeZone(abbreviation: "UTC")
                    return formatter
                }()
            ]

            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }

            // Try ISO8601DateFormatter as fallback
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }

        // Use ISO8601 for encoding
        encoder.dateEncodingStrategy = .iso8601

        // Load stored tokens
        loadStoredTokens()

        // Setup network reachability monitoring
        setupNetworkMonitor()
    }

    // MARK: - Public API Methods

    /// Make a generic request
    func request<T: Codable>(_ endpoint: APIEndpoint, responseType: T.Type) async throws -> T {
        // Check if token is expired before making authenticated requests
        if endpoint.requiresAuth && isTokenExpired() {
            AppLogger.info("Token expired, attempting refresh before request", category: .authentication)
            try await refreshTokenIfNeeded()
        }

        let request = try buildURLRequest(for: endpoint)

        // Log detailed request information
        AppLogger.network("\(request.httpMethod ?? "Unknown") request", url: request.url?.absoluteString)

        do {
            let (data, response) = try await session.data(for: request)

            // Handle HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                AppLogger.error("Invalid response type", category: .networking)
                throw NetworkError.unknownError(NSError(domain: "NetworkManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]))
            }

            // Log response summary
            AppLogger.network("Response received", statusCode: httpResponse.statusCode)

            // For AI generation errors, log the response body to see validation details
            if endpoint.path.contains("/ai/generate-meal-plan/") && httpResponse.statusCode >= 400 {
                if let responseString = String(data: data, encoding: .utf8) {
                    AppLogger.error("AI Generation Error Response: \(responseString)", category: .aiGeneration)
                }
            }

            // Check for authentication errors
            if httpResponse.statusCode == 401 {
                if endpoint.requiresAuth {
                    // Try to refresh token
                    try await refreshTokenIfNeeded()
                    // Retry the original request
                    return try await self.request(endpoint, responseType: responseType)
                } else {
                    throw NetworkError.authenticationRequired
                }
            }

            // Check for other HTTP errors
            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let message = errorMessage?["error"] as? String ?? errorMessage?["detail"] as? String
                throw NetworkError.serverError(httpResponse.statusCode, message)
            }

            // Handle empty responses (like DELETE operations)
            if data.isEmpty && httpResponse.statusCode == 204 {
                // Return empty object for 204 No Content
                if T.self == EmptyResponse.self {
                    return EmptyResponse() as! T
                }
            }

            // Decode response
            do {
                let decodedResponse = try decoder.decode(T.self, from: data)
                return decodedResponse
            } catch {
                AppLogger.error("Decoding failed for \(T.self): \(error)", category: .networking)

                // For AI endpoints, log the raw response to help debug
                if endpoint.path.contains("/ai/") {
                    if let responseString = String(data: data, encoding: .utf8) {
                        AppLogger.debug("Raw response for \(endpoint.path): \(responseString)", category: .networking)
                    }
                }

                throw NetworkError.decodingError(error)
            }

        } catch let error as NetworkError {
            throw error
        } catch {
            if (error as NSError).code == NSURLErrorTimedOut {
                throw NetworkError.requestTimeout
            } else if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                throw NetworkError.networkUnavailable
            } else {
                throw NetworkError.unknownError(error)
            }
        }
    }

    /// Make an authenticated request
    func authenticatedRequest<T: Codable>(_ endpoint: APIEndpoint, responseType: T.Type) async throws -> T {
        var authenticatedEndpoint = endpoint
        authenticatedEndpoint = APIEndpoint(
            path: endpoint.path,
            method: endpoint.method,
            body: endpoint.body,
            queryItems: endpoint.queryItems,
            requiresAuth: true
        )

        return try await request(authenticatedEndpoint, responseType: responseType)
    }

    // MARK: - Authentication Methods

    func setTokens(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken

        // Set session expiry to 30 days from now
        self.sessionExpiry = Calendar.current.date(byAdding: .day, value: 30, to: Date())

        Task { @MainActor in
            self.isAuthenticated = true
        }
        storeTokens()

        AppLogger.info("Session set for 30 days, expires: \(sessionExpiry?.description ?? "unknown")", category: .authentication)
    }

    func clearTokens() {
        self.accessToken = nil
        self.refreshToken = nil
        self.sessionExpiry = nil
        Task { @MainActor in
            self.isAuthenticated = false
        }
        clearStoredTokens()

        AppLogger.info("Session cleared", category: .authentication)
    }

    func isTokenExpired() -> Bool {
        guard let accessToken = accessToken else { return true }

        // Simple JWT token expiration check
        let tokenParts = accessToken.split(separator: ".")
        guard tokenParts.count == 3 else {
            AppLogger.warning("Invalid JWT token format, assuming expired", category: .authentication)
            return true
        }

        // Decode the payload (add padding if needed for base64 decoding)
        var payload = String(tokenParts[1])
        while payload.count % 4 != 0 {
            payload += "="
        }

        guard let payloadData = Data(base64Encoded: payload),
              let payloadDict = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = payloadDict["exp"] as? TimeInterval else {
            AppLogger.warning("Unable to parse token expiration, assuming expired", category: .authentication)
            return true
        }

        let tokenExpirationDate = Date(timeIntervalSince1970: exp)
        let currentDate = Date()
        let isTokenExpired = currentDate >= tokenExpirationDate

        // Also check session expiry (30-day limit)
        let isSessionExpired = if let sessionExpiry = sessionExpiry {
            currentDate >= sessionExpiry
        } else {
            true // No session expiry set, assume expired
        }

        let isExpired = isTokenExpired || isSessionExpired

        AppLogger.debug("Token expired: \(isTokenExpired), Session expired: \(isSessionExpired), Overall expired: \(isExpired)", category: .authentication)

        if isTokenExpired {
            AppLogger.warning("Access token has expired", category: .authentication)
        }
        if isSessionExpired {
            AppLogger.warning("30-day session has expired", category: .authentication)
        }

        return isExpired
    }

    func refreshTokenIfNeeded() async throws {
        guard let refreshToken = refreshToken else {
            throw NetworkError.authenticationRequired
        }

        let refreshEndpoint = APIEndpoint(
            path: "/auth/token/refresh/",
            method: .POST,
            body: try encoder.encode(["refresh": refreshToken]),
            requiresAuth: false
        )

        do {
            let response: TokenRefreshResponse = try await self.request(refreshEndpoint, responseType: TokenRefreshResponse.self)
            self.accessToken = response.access

            // Renew session for another 30 days on token refresh
            self.sessionExpiry = Calendar.current.date(byAdding: .day, value: 30, to: Date())

            storeTokens()

            AppLogger.info("Token refreshed and session renewed for 30 days", category: .authentication)
        } catch {
            // If refresh fails, clear tokens and require re-authentication
            clearTokens()
            throw NetworkError.tokenExpired
        }
    }

    /// Extract user ID from the current access token
    func getCurrentUserID() -> String? {
        guard let accessToken = accessToken else { return nil }

        guard let payload = decodeJWTPayload(token: accessToken) else {
            AppLogger.error("Failed to decode JWT payload for userId", category: .authentication)
            return nil
        }

        // Try common JWT claims for user ID
        if let userId = payload["user_id"] as? String {
            return userId
        } else if let userId = payload["sub"] as? String {
            return userId
        } else if let userId = payload["user_id"] as? Int {
            return String(userId)
        }

        AppLogger.warning("No user_id found in JWT token payload", category: .authentication)
        return nil
    }

    // MARK: - Private Helper Methods

    private func buildURLRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        // Build URL
        guard var urlComponents = URLComponents(string: baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }

        // Add query parameters
        if let queryItems = endpoint.queryItems {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add authentication header if required
        if endpoint.requiresAuth, let accessToken = accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            // Debug JWT token information
            AppLogger.debug("Using auth token", category: .authentication)
        } else if endpoint.requiresAuth {
            AppLogger.warning("Auth required but no access token available", category: .authentication)
        }

        // Add request body
        if let body = endpoint.body {
            request.httpBody = body
        }

        return request
    }

    private func loadStoredTokens() {
        // Load tokens securely from Keychain
        self.accessToken = keychain.get("MealPrepApp_access_token")
        self.refreshToken = keychain.get("MealPrepApp_refresh_token")

        // Load session expiry
        if let expiryString = keychain.get("MealPrepApp_session_expiry"),
           let expiryInterval = TimeInterval(expiryString) {
            self.sessionExpiry = Date(timeIntervalSince1970: expiryInterval)
        }

        // Only set authenticated if we have both tokens and they're not expired
        let hasTokens = accessToken != nil && refreshToken != nil
        let tokensValid = hasTokens && !isTokenExpired()

        Task { @MainActor in
            self.isAuthenticated = tokensValid
        }

        // Debug logging
        AppLogger.info("Tokens loaded, authenticated: \(tokensValid)", category: .authentication)
        if let expiry = sessionExpiry {
            AppLogger.debug("Session expires at: \(expiry)", category: .authentication)
        }
    }

    private func storeTokens() {
        // Store tokens securely in Keychain
        if let accessToken = accessToken {
            keychain.set(accessToken, forKey: "MealPrepApp_access_token")
        }
        if let refreshToken = refreshToken {
            keychain.set(refreshToken, forKey: "MealPrepApp_refresh_token")
        }

        // Store session expiry
        if let sessionExpiry = sessionExpiry {
            let expiryString = String(sessionExpiry.timeIntervalSince1970)
            keychain.set(expiryString, forKey: "MealPrepApp_session_expiry")
        }
    }

    private func clearStoredTokens() {
        keychain.delete("MealPrepApp_access_token")
        keychain.delete("MealPrepApp_refresh_token")
        keychain.delete("MealPrepApp_session_expiry")
    }

    private func setupNetworkMonitor() {
        let monitor = NWPathMonitor()
        self.pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = (path.status == .satisfied)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        pathMonitor?.cancel()
    }

    // MARK: - URL Configuration

    private static func getBaseURL() -> String {
//        return "https://meal-prep-app-backend.vercel.app/api"
        #if DEBUG
        return "http://127.0.0.1:8000/api"
        #else
        return "https://meal-prep-app-backend.vercel.app/api"
        #endif
    }
}

// MARK: - Response Models

struct EmptyResponse: Codable {
    init() {}
}

struct TokenRefreshResponse: Codable {
    let access: String
}

// MARK: - Convenience Extensions

extension NetworkManager {

    // GET request
    func get<T: Codable>(_ path: String, queryItems: [URLQueryItem]? = nil, responseType: T.Type, requiresAuth: Bool = true) async throws -> T {
        let endpoint = APIEndpoint(path: path, method: .GET, queryItems: queryItems, requiresAuth: requiresAuth)
        return try await request(endpoint, responseType: responseType)
    }

    // POST request
    func post<T: Codable, U: Codable>(_ path: String, body: T, responseType: U.Type, requiresAuth: Bool = true) async throws -> U {
        let bodyData = try encoder.encode(body)

        // DEBUG: Special logging for recipe creation and AI endpoints
        if path.contains("/recipes") || path.contains("/ai/") {
            AppLogger.debug("POST endpoint: \(path)", category: .networking)

            if let bodyString = String(data: bodyData, encoding: .utf8) {
                // For AI meal plan generation, log FULL REQUEST PAYLOAD to debug validation error
                if path.contains("/ai/generate-meal-plan/") {
                    AppLogger.debug("AI Generation Request JSON: \(bodyString)", category: .aiGeneration)

                    // Parse and validate each required field
                    do {
                        if let jsonData = bodyString.data(using: .utf8),
                           let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                            AppLogger.debug("Parsed JSON fields:", category: .aiGeneration)
                            for (key, value) in jsonObject {
                                AppLogger.debug("  \(key): \(value)", category: .aiGeneration)

                                // Check if plan_description is valid
                                if key == "plan_description" {
                                    let desc = value as? String ?? ""
                                    if desc.isEmpty {
                                        AppLogger.warning("plan_description is EMPTY!", category: .aiGeneration)
                                    } else if desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        AppLogger.warning("plan_description is only whitespace!", category: .aiGeneration)
                                    } else {
                                        AppLogger.debug("plan_description is valid: '\(desc)'", category: .aiGeneration)
                                    }
                                }
                            }
                        }
                    } catch {
                        AppLogger.error("Failed to parse JSON: \(error)", category: .aiGeneration)
                    }
                }

                // Try to extract image_url from the request body if it's a recipe
                if let range = bodyString.range(of: "\"image_url\":\"[^\"]*\"", options: .regularExpression) {
                    let imageUrlPart = String(bodyString[range])
                    AppLogger.debug("Request body contains: \(imageUrlPart)", category: .networking)
                } else if bodyString.contains("image_url") {
                    AppLogger.debug("Request body contains image_url field but could not extract value", category: .networking)
                } else {
                    AppLogger.debug("Request body does NOT contain image_url field", category: .networking)
                }

                // Show first 500 chars of body for debugging (unless it's AI generation - we logged full above)
                if !path.contains("/ai/generate-meal-plan/") {
                    let bodyPreview = String(bodyString.prefix(500))
                    AppLogger.debug("Request body preview: \(bodyPreview)", category: .networking)
                }
            }
        }

        let endpoint = APIEndpoint(path: path, method: .POST, body: bodyData, requiresAuth: requiresAuth)
        let result = try await request(endpoint, responseType: responseType)

        // DEBUG: Special logging for recipe creation responses
        if path.contains("/recipes") || path.contains("/ai/") {
            do {
                let responseData = try encoder.encode(result)
                if let responseString = String(data: responseData, encoding: .utf8) {
                    if let range = responseString.range(of: "\"image_url\":\"[^\"]*\"", options: .regularExpression) {
                        let imageUrlPart = String(responseString[range])
                        AppLogger.debug("Response contains: \(imageUrlPart)", category: .networking)
                    } else if responseString.contains("image_url") {
                        AppLogger.debug("Response contains image_url field but could not extract value", category: .networking)
                    } else {
                        AppLogger.debug("Response does NOT contain image_url field", category: .networking)
                    }
                }
            } catch {
                AppLogger.debug("Could not encode response for debugging", category: .networking)
            }
        }

        return result
    }

    // PUT request
    func put<T: Codable, U: Codable>(_ path: String, body: T, responseType: U.Type, requiresAuth: Bool = true) async throws -> U {
        let bodyData = try encoder.encode(body)
        let endpoint = APIEndpoint(path: path, method: .PUT, body: bodyData, requiresAuth: requiresAuth)
        return try await request(endpoint, responseType: responseType)
    }

    // PATCH request
    func patch<T: Codable, U: Codable>(_ path: String, body: T, responseType: U.Type, requiresAuth: Bool = true) async throws -> U {
        let bodyData = try encoder.encode(body)
        let endpoint = APIEndpoint(path: path, method: .PATCH, body: bodyData, requiresAuth: requiresAuth)
        return try await request(endpoint, responseType: responseType)
    }

    // DELETE request
    func delete(_ path: String, requiresAuth: Bool = true) async throws {
        let endpoint = APIEndpoint(path: path, method: .DELETE, requiresAuth: requiresAuth)
        let _: EmptyResponse = try await request(endpoint, responseType: EmptyResponse.self)
    }

    // MARK: - JWT Debugging Helper

    func decodeJWTPayload(token: String) -> [String: Any]? {
        let segments = token.components(separatedBy: ".")
        guard segments.count == 3 else {
            AppLogger.error("Invalid JWT format - expected 3 segments, got \(segments.count)", category: .authentication)
            return nil
        }

        let payloadSegment = segments[1]

        // Add padding if needed (JWT base64 might not have padding)
        var base64 = payloadSegment
        while base64.count % 4 != 0 {
            base64 += "="
        }

        // Decode base64
        guard let data = Data(base64Encoded: base64) else {
            AppLogger.error("Failed to decode base64 payload", category: .authentication)
            return nil
        }

        // Parse JSON
        do {
            let payload = try JSONSerialization.jsonObject(with: data, options: [])
            return payload as? [String: Any]
        } catch {
            AppLogger.error("Failed to parse JSON payload: \(error)", category: .authentication)
            return nil
        }
    }
}
