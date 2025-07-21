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
    
    @Test("Error mapping works correctly")
    func testErrorMapping() async throws {
        let errorHandler = ErrorHandler.shared
        
        // Test URL errors
        let urlError = URLError(.notConnectedToInternet)
        errorHandler.handle(urlError)
        
        #expect(errorHandler.currentError != nil)
        #expect(errorHandler.isShowingError == true)
        
        errorHandler.clearError()
        #expect(errorHandler.currentError == nil)
        #expect(errorHandler.isShowingError == false)
    }
    
    @Test("Notifications are added and dismissed correctly")
    func testNotifications() async throws {
        let errorHandler = ErrorHandler.shared
        
        // Clear any existing notifications
        errorHandler.dismissAllNotifications()
        #expect(errorHandler.notifications.isEmpty)
        
        // Add a success notification
        errorHandler.showSuccess("Test success")
        #expect(errorHandler.notifications.count == 1)
        #expect(errorHandler.notifications.first?.type == .success)
        
        // Add an info notification
        errorHandler.showInfo("Test info")
        #expect(errorHandler.notifications.count == 2)
        
        // Clear all notifications
        errorHandler.dismissAllNotifications()
        #expect(errorHandler.notifications.isEmpty)
    }
    
    @Test("AppError types conform to Equatable")
    func testErrorEquality() async throws {
        let error1 = AppError.network(.noConnection)
        let error2 = AppError.network(.noConnection)
        let error3 = AppError.network(.timeout)
        
        #expect(error1 == error2)
        #expect(error1 != error3)
        
        let authError1 = AppError.authentication(.invalidCredentials)
        let authError2 = AppError.authentication(.invalidCredentials)
        
        #expect(authError1 == authError2)
        #expect(authError1 != error1)
    }
}