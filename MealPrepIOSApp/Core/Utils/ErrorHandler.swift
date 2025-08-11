//
//  ErrorHandler.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - App Error
struct AppError: Identifiable {
    let id = UUID()
    let error: Error
    let localizedDescription: String?
    let recoverySuggestion: String?
    let isRetryable: Bool

    init(error: Error, isRetryable: Bool = false) {
        self.error = error
        self.localizedDescription = error.localizedDescription

        if let networkError = error as? NetworkError {
            self.recoverySuggestion = ErrorHandler.shared.getUserFriendlyMessage(for: networkError)
            self.isRetryable = networkError.isRetryable
        } else {
            self.recoverySuggestion = nil
            self.isRetryable = isRetryable
        }
    }

    init(message: String, suggestion: String? = nil, isRetryable: Bool = false) {
        self.error = NSError(domain: "MealPrepApp", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
        self.localizedDescription = message
        self.recoverySuggestion = suggestion
        self.isRetryable = isRetryable
    }
}

// MARK: - Notification Type
enum NotificationType {
    case success
    case error
    case warning
    case info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

// MARK: - App Notification
struct AppNotification: Identifiable {
    let id = UUID()
    let type: NotificationType
    let message: String
    let duration: TimeInterval

    init(type: NotificationType, message: String, duration: TimeInterval = 3.0) {
        self.type = type
        self.message = message
        self.duration = duration
    }

    static func success(_ message: String, duration: TimeInterval = 3.0) -> AppNotification {
        AppNotification(type: .success, message: message, duration: duration)
    }

    static func error(_ error: AppError, duration: TimeInterval = 5.0) -> AppNotification {
        AppNotification(type: .error, message: error.localizedDescription ?? "Unknown error", duration: duration)
    }

    static func warning(_ message: String, duration: TimeInterval = 4.0) -> AppNotification {
        AppNotification(type: .warning, message: message, duration: duration)
    }

    static func info(_ message: String, duration: TimeInterval = 3.0) -> AppNotification {
        AppNotification(type: .info, message: message, duration: duration)
    }
}

// MARK: - Network Error Extension
extension NetworkError {
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .requestTimeout:
            return true
        case .serverError(let code, _):
            return code >= 500
        default:
            return false
        }
    }
}

// MARK: - Error Handler
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()

    @Published var currentError: AppError?
    @Published var isShowingError = false
    @Published var notifications: [AppNotification] = []

    private var notificationTimers: [UUID: Timer] = [:]

    private init() {}

    func handle(_ error: Error, context: String) {
        AppLogger.error("Error in \(context): \(error.localizedDescription)", category: .error)

        // Log additional details for NetworkError with structured logging
        if let networkError = error as? NetworkError {
            switch networkError {
            case .serverError(let code, let message):
                AppLogger.error("Server Error \(code): \(message ?? "No message")", category: .networking)
            case .authenticationRequired:
                AppLogger.warning("Authentication required", category: .authentication)
            case .tokenExpired:
                AppLogger.warning("Token expired - refresh needed", category: .authentication)
            case .decodingError(let decodingError):
                AppLogger.error("Decoding error: \(decodingError.localizedDescription)", category: .networking)
            case .networkUnavailable:
                AppLogger.warning("Network unavailable", category: .networking)
            case .requestTimeout:
                AppLogger.warning("Request timeout", category: .networking)
            default:
                AppLogger.error("Network error: \(networkError.localizedDescription)", category: .networking)
            }
        }
    }

    func getUserFriendlyMessage(for error: Error) -> String {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .authenticationRequired, .tokenExpired:
                return "Please log in again to continue."
            case .networkUnavailable:
                return "Please check your internet connection and try again."
            case .serverError(let code, _):
                switch code {
                case 400:
                    return "Invalid request. Please check your input and try again."
                case 401:
                    return "Authentication required. Please log in again."
                case 403:
                    return "Access denied. You don't have permission for this action."
                case 404:
                    return "The requested item was not found."
                case 409:
                    return "This action conflicts with existing data. Please refresh and try again."
                case 422:
                    return "The data provided is invalid. Please check your input."
                case 429:
                    return "Too many requests. Please wait a moment and try again."
                case 500...599:
                    return "Server is temporarily unavailable. Please try again later."
                default:
                    return "Something went wrong (Error \(code)). Please try again."
                }
            case .requestTimeout:
                return "Request timed out. Please check your connection and try again."
            case .decodingError:
                return "Data format error. Please try refreshing the app."
            case .invalidURL:
                return "Invalid request. Please contact support if this persists."
            case .noData:
                return "No data received. Please try again."
            case .unknownError:
                return "An unexpected error occurred. Please try again."
            }
        }

        // Handle Core Data errors
        if (error as NSError).domain == "NSCocoaErrorDomain" {
            return "Data storage error. Please restart the app and try again."
        }
        
        // Handle other common errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "No internet connection. Please check your network settings."
            case .timedOut:
                return "Connection timed out. Please try again."
            case .cannotConnectToHost:
                return "Cannot connect to server. Please try again later."
            default:
                return "Network error. Please check your connection and try again."
            }
        }

        return error.localizedDescription
    }

    // MARK: - Error Management

    func showError(_ error: AppError) {
        AppLogger.error("Showing error to user: \(error.localizedDescription ?? "Unknown error")", category: .userInterface)
        DispatchQueue.main.async {
            self.currentError = error
            self.isShowingError = true
        }
    }

    func showError(_ error: Error, isRetryable: Bool = false) {
        let appError = AppError(error: error, isRetryable: isRetryable)
        showError(appError)
    }

    func showError(message: String, suggestion: String? = nil, isRetryable: Bool = false) {
        let appError = AppError(message: message, suggestion: suggestion, isRetryable: isRetryable)
        showError(appError)
    }

    func clearError() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.isShowingError = false
        }
    }

    // MARK: - Notification Management

    func showNotification(_ notification: AppNotification) {
        AppLogger.info("Showing \(notification.type) notification: \(notification.message)", category: .userInterface)
        DispatchQueue.main.async {
            self.notifications.append(notification)

            // Set up auto-dismiss timer
            let timer = Timer.scheduledTimer(withTimeInterval: notification.duration, repeats: false) { [weak self] _ in
                self?.dismissNotification(notification)
            }
            self.notificationTimers[notification.id] = timer
        }
    }

    func showSuccess(_ message: String) {
        showNotification(.success(message))
    }

    func showWarning(_ message: String) {
        showNotification(.warning(message))
    }

    func showInfo(_ message: String) {
        showNotification(.info(message))
    }

    func dismissNotification(_ notification: AppNotification) {
        DispatchQueue.main.async {
            self.notifications.removeAll { $0.id == notification.id }
            self.notificationTimers[notification.id]?.invalidate()
            self.notificationTimers.removeValue(forKey: notification.id)
        }
    }

    func clearAllNotifications() {
        DispatchQueue.main.async {
            self.notifications.removeAll()
            self.notificationTimers.values.forEach { $0.invalidate() }
            self.notificationTimers.removeAll()
        }
    }
}