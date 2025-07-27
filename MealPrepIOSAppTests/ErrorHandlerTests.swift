//
//  ErrorHandlerTests.swift
//  MealPrepIOSAppTests
//
//  Created by AI Assistant on 7/21/25.
//

import Testing
import Foundation
@testable import MealPrepIOSApp

@MainActor
struct ErrorHandlerTests {
    
    @Test("Error handling works correctly")
    func testErrorHandling() async throws {
        let errorHandler = ErrorHandler.shared
        
        // Clear any existing state
        await MainActor.run {
            errorHandler.clearError()
        }
        
        // Test URL errors
        let urlError = URLError(.notConnectedToInternet)
        errorHandler.handle(urlError, context: "test")
        
        // Test showing error
        await MainActor.run {
            errorHandler.showError(urlError)
        }
        
        // Allow UI updates to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        #expect(errorHandler.currentError != nil)
        #expect(errorHandler.isShowingError == true)
        
        await MainActor.run {
            errorHandler.clearError()
        }
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        #expect(errorHandler.currentError == nil)
        #expect(errorHandler.isShowingError == false)
    }
    
    @Test("Notifications are added and dismissed correctly")
    func testNotifications() async throws {
        let errorHandler = ErrorHandler.shared
        
        // Clear any existing notifications
        await MainActor.run {
            errorHandler.clearAllNotifications()
        }
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        #expect(errorHandler.notifications.isEmpty)
        
        // Add a success notification
        await MainActor.run {
            errorHandler.showSuccess("Test success")
        }
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        #expect(errorHandler.notifications.count == 1)
        #expect(errorHandler.notifications.first?.type == .success)
        
        // Add an info notification
        await MainActor.run {
            errorHandler.showInfo("Test info")
        }
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        #expect(errorHandler.notifications.count == 2)
        
        // Clear all notifications
        await MainActor.run {
            errorHandler.clearAllNotifications()
        }
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        #expect(errorHandler.notifications.isEmpty)
    }
    
    @Test("AppError initialization works correctly")
    func testAppErrorInit() async throws {
        // Test AppError with message
        let error1 = AppError(message: "Test error")
        #expect(error1.localizedDescription == "Test error")
        #expect(error1.isRetryable == false)
        
        // Test AppError with NSError
        let nsError = NSError(domain: "test", code: 404, userInfo: [NSLocalizedDescriptionKey: "Not found"])
        let error2 = AppError(error: nsError, isRetryable: true)
        #expect(error2.localizedDescription == "Not found")
        #expect(error2.isRetryable == true)
        
        // Test AppError with suggestion
        let error3 = AppError(message: "Test", suggestion: "Try again", isRetryable: true)
        #expect(error3.recoverySuggestion == "Try again")
        #expect(error3.isRetryable == true)
    }
    
    @Test("User friendly messages work correctly")
    func testUserFriendlyMessages() async throws {
        let errorHandler = ErrorHandler.shared
        
        // Test network error
        let networkError = NetworkError.networkUnavailable
        let message = errorHandler.getUserFriendlyMessage(for: networkError)
        #expect(message.contains("internet connection"))
        
        // Test generic error
        let genericError = NSError(domain: "test", code: 0, userInfo: [NSLocalizedDescriptionKey: "Generic error"])
        let genericMessage = errorHandler.getUserFriendlyMessage(for: genericError)
        #expect(genericMessage == "Generic error")
    }
}