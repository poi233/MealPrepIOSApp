//
//  AppError.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/21/25.
//

import Foundation

// MARK: - App Error Types
enum AppErrorType {
    case general(String)
    case network(Error)
    case validation(String)
    case authentication(String)
    case server(Int, String)
    case notFound(String)
    case unknown(Error)
    
    var message: String {
        switch self {
        case .general(let message):
            return message
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        case .validation(let message):
            return "Validation error: \(message)"
        case .authentication(let message):
            return "Authentication error: \(message)"
        case .server(let code, let message):
            return "Server error (\(code)): \(message)"
        case .notFound(let message):
            return "Not found: \(message)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .network:
            return true
        case .server(let code, _):
            return code >= 500
        default:
            return false
        }
    }
}