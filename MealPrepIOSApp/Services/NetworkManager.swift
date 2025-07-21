//
//  NetworkManager.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import Foundation
import KeychainSwift
import Reachability
import Combine

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
@MainActor
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
    private var reachability: Reachability?
    
    private init() {
        // Configure URLSession with custom configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.waitsForConnectivity = true
        
        self.session = URLSession(configuration: config)
        
        // Environment-based URL configuration
        #if DEBUG
        self.baseURL = "http://127.0.0.1:8000/api"
        #else
        self.baseURL = "https://meal-prep-app-backend.vercel.app/api"
        #endif
        
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
        setupReachability()
    }
    
    // MARK: - Public API Methods
    
    /// Make a generic request
    func request<T: Codable>(_ endpoint: APIEndpoint, responseType: T.Type) async throws -> T {
        let request = try buildURLRequest(for: endpoint)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Handle HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknownError(NSError(domain: "NetworkManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]))
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
                print("=== DECODING ERROR ===")
                print("Error: \(error)")
                print("Expected type: \(T.self)")
                print("Response data: \(String(data: data, encoding: .utf8) ?? "Unable to convert to string")")
                print("HTTP Status: \(httpResponse.statusCode)")
                print("======================")
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
        self.isAuthenticated = true
        storeTokens()
    }
    
    func clearTokens() {
        self.accessToken = nil
        self.refreshToken = nil
        self.isAuthenticated = false
        clearStoredTokens()
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
            storeTokens()
        } catch {
            // If refresh fails, clear tokens and require re-authentication
            clearTokens()
            throw NetworkError.tokenExpired
        }
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
        
        // Only set authenticated if we have both tokens
        self.isAuthenticated = accessToken != nil && refreshToken != nil
        
        // Debug logging
        print("NetworkManager: Loaded tokens - Access: \(accessToken != nil), Refresh: \(refreshToken != nil), Authenticated: \(isAuthenticated)")
    }
    
    private func storeTokens() {
        // Store tokens securely in Keychain
        if let accessToken = accessToken {
            keychain.set(accessToken, forKey: "MealPrepApp_access_token")
        }
        if let refreshToken = refreshToken {
            keychain.set(refreshToken, forKey: "MealPrepApp_refresh_token")
        }
    }
    
    private func clearStoredTokens() {
        keychain.delete("MealPrepApp_access_token")
        keychain.delete("MealPrepApp_refresh_token")
    }
    
    private func setupReachability() {
        do {
            reachability = try Reachability()
            
            reachability?.whenReachable = { [weak self] reachability in
                DispatchQueue.main.async {
                    self?.isConnected = true
                }
            }
            
            reachability?.whenUnreachable = { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
            }
            
            try reachability?.startNotifier()
        } catch {
            print("Unable to start reachability notifier: \(error)")
        }
    }
    
    deinit {
        reachability?.stopNotifier()
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
        let endpoint = APIEndpoint(path: path, method: .POST, body: bodyData, requiresAuth: requiresAuth)
        return try await request(endpoint, responseType: responseType)
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
}