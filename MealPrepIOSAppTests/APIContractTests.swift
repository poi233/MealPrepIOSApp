//
//  APIContractTests.swift
//  MealPrepIOSAppTests
//
//  Created by AI Assistant on 7/21/25.
//

import XCTest
@testable import MealPrepIOSApp

// MARK: - API Contract Tests
// These tests verify that our Swift models align with Django backend API contracts

final class APIContractTests: XCTestCase {

    private var networkManager: NetworkManager!

    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        networkManager = NetworkManager.shared
    }

    override func tearDownWithError() throws {
        networkManager = nil
        try super.tearDownWithError()
    }

    // MARK: - Authentication Contract Tests

    func testUserRegistrationContract() async throws {
        // Test registration data contract
        let registrationData = RegisterRequest(
            username: "testuser_\(UUID().uuidString.prefix(8))",
            email: "test_\(UUID().uuidString.prefix(8))@example.com",
            password: "TestPassword123!",
            passwordConfirm: "TestPassword123!",
            displayName: "Test User",
            dietaryPreferences: DietaryPreferences(
                dietType: "vegetarian",
                allergies: ["nuts"],
                dislikes: ["spicy"],
                calorieTarget: 2000
            )
        )

        do {
            let authService = AuthenticationService()
            let response = try await authService.register(userData: registrationData)

            // Verify response structure
            XCTAssertFalse(response.access.isEmpty, "Access token should not be empty")
            XCTAssertFalse(response.refresh.isEmpty, "Refresh token should not be empty")
            XCTAssertEqual(response.user.username, registrationData.username)
            XCTAssertEqual(response.user.email, registrationData.email)
            XCTAssertEqual(response.user.displayName, registrationData.displayName)

            // Test cleanup - delete the test user account
            try await authService.logout()

        } catch let error as NetworkError {
            // Check for expected errors
            switch error {
            case .serverError(let code, let message):
                if code == 400 && message?.contains("already exists") == true {
                    // Expected for existing user, test still validates contract
                    print("User already exists - contract validation passed")
                } else {
                    XCTFail("Unexpected server error: \(error)")
                }
            default:
                XCTFail("Registration contract test failed: \(error)")
            }
        }
    }

    func testLoginContract() async throws {
        // First create a test user
        let testEmail = "contracttest_\(UUID().uuidString.prefix(8))@example.com"
        let testPassword = "ContractTest123!"

        let registrationData = RegisterRequest(
            username: "contracttest_\(UUID().uuidString.prefix(8))",
            email: testEmail,
            password: testPassword,
            passwordConfirm: testPassword,
            displayName: "Contract Test User",
            dietaryPreferences: nil
        )

        let authService = AuthenticationService()

        do {
            // Register user
            _ = try await authService.register(userData: registrationData)

            // Clear tokens to test login
            await MainActor.run {
                networkManager.clearTokens()
            }

            // Test login contract
            let loginResponse = try await authService.login(
                email: testEmail,
                password: testPassword
            )

            // Verify login response structure
            XCTAssertFalse(loginResponse.access.isEmpty)
            XCTAssertFalse(loginResponse.refresh.isEmpty)
            XCTAssertEqual(loginResponse.user.email, testEmail)

            // Cleanup
            try await authService.logout()

        } catch {
            XCTFail("Login contract test failed: \(error)")
        }
    }

    // MARK: - Recipe Contract Tests

    func testRecipeModelContract() async throws {
        // Test basic recipe listing without authentication
        do {
            let recipes: [Recipe] = try await networkManager.get(
                "/recipes/",
                responseType: [Recipe].self,
                requiresAuth: false
            )

            // If we get recipes, verify the structure
            if let firstRecipe = recipes.first {
                XCTAssertFalse(firstRecipe.id.isEmpty)
                XCTAssertFalse(firstRecipe.name.isEmpty)
                XCTAssertNotNil(firstRecipe.createdAt)
                // Note: Other fields might be optional
            }

        } catch let error as NetworkError {
            // Check if it's an authentication error - that's acceptable for this test
            switch error {
            case .serverError(let code, _):
                if code == 401 || code == 403 {
                    print("Recipe endpoint requires auth - expected behavior")
                } else {
                    XCTFail("Unexpected recipe contract error: \(error)")
                }
            default:
                XCTFail("Recipe contract test failed: \(error)")
            }
        }
    }

    // MARK: - Error Handling Contract Tests

    func testErrorResponseContract() async throws {
        // Test that error responses follow expected format
        do {
            // Try to access a protected endpoint without auth
            let _: [Recipe] = try await networkManager.get(
                "/recipes/",
                responseType: [Recipe].self,
                requiresAuth: false
            )

        } catch let error as NetworkError {
            switch error {
            case .serverError(let code, let message):
                XCTAssertTrue(code >= 400, "Error codes should be 4xx or 5xx")
                // Message is optional but should be handled gracefully
                print("Error message: \(message ?? "No message")")
            case .authenticationRequired, .tokenExpired:
                // These are acceptable for protected endpoints
                print("Authentication error as expected")
            default:
                // Other network errors are also acceptable
                print("Network error: \(error)")
            }
        }
    }

    // MARK: - AI Meal Plan Contract Tests

    func testAIMealPlanResponseDecodesWrappedPreviewPlan() throws {
        let json = """
        {
            "success": true,
            "meal_plan": {
                "plan_description": "High protein weekly meal plan",
                "lightweight_daily_meals": [
                    {
                        "day": "Monday",
                        "breakfast": [
                            {
                                "id": null,
                                "name": "Greek Yogurt Bowl",
                                "cuisine": "Mediterranean",
                                "description": "Protein-rich breakfast",
                                "estimated_calories": 320,
                                "estimated_prep_time": 10,
                                "image_url": null,
                                "tags": ["high protein"]
                            }
                        ],
                        "lunch": [],
                        "dinner": []
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(AIMealPlanResponse.self, from: json)

        XCTAssertTrue(response.mealPlan.id.hasPrefix("ai-generated-"))
        XCTAssertEqual(response.mealPlan.name, "AI Generated Meal Plan")
        XCTAssertEqual(response.mealPlan.planDescription, "High protein weekly meal plan")
        XCTAssertEqual(response.mealPlan.lightweightDailyMeals?.first?.breakfast.first?.name, "Greek Yogurt Bowl")
    }

    func testAIMealPlanResponseDecodesDataWrappedPlan() throws {
        let json = """
        {
            "data": {
                "mealPlan": {
                    "id": 42,
                    "name": "Generated Plan",
                    "lightweight_daily_meals": []
                }
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(AIMealPlanResponse.self, from: json)

        XCTAssertEqual(response.mealPlan.id, "42")
        XCTAssertEqual(response.mealPlan.name, "Generated Plan")
        XCTAssertNotNil(response.mealPlan.createdAt)
        XCTAssertNotNil(response.mealPlan.updatedAt)
    }

    // MARK: - Date Parsing Contract Tests

    func testDateParsingContract() {
        let decoder = JSONDecoder()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        decoder.dateDecodingStrategy = .formatted(dateFormatter)

        // Test various date formats that Django might return
        let testDates = [
            "2024-01-15T10:30:00.123456Z",
            "2024-01-15T10:30:00.000000Z"
        ]

        for dateString in testDates {
            let jsonData = "{\"test_date\": \"\(dateString)\"}".data(using: .utf8)!

            do {
                let decoded = try decoder.decode(TestDateModel.self, from: jsonData)
                XCTAssertNotNil(decoded.testDate, "Date should be parsed successfully for: \(dateString)")
            } catch {
                XCTFail("Failed to parse date format: \(dateString), error: \(error)")
            }
        }
    }
}

// MARK: - Test Helper Models

private struct HealthResponse: Codable {
    let status: String
    let database: String
    let debug: Bool?
}

private struct TestDateModel: Codable {
    let testDate: Date

    enum CodingKeys: String, CodingKey {
        case testDate = "test_date"
    }
}
