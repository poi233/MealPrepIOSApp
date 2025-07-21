import Foundation

// Test data matching the actual API response
let testJSON = """
{
    "id": "39e7f25b-3800-4aba-adee-5b6d4bba8ecc",
    "user_id": "3ca67ae7-2d91-479c-940b-e868085d5710",
    "name": "猫猫",
    "description": "",
    "week_start_date": "2025-07-21",
    "is_active": false,
    "items_count": 0,
    "created_at": "2025-07-20T08:21:52.001886Z",
    "updated_at": "2025-07-20T18:54:17.594007Z"
}
""".data(using: .utf8)!

do {
    let mealPlan = try JSONDecoder().decode(MealPlan.self, from: testJSON)
    print("✅ Successfully parsed MealPlan:")
    print("   ID: \(mealPlan.id)")
    print("   Name: \(mealPlan.name)")
    print("   Week Start Date: \(mealPlan.weekStartDate)")
    print("   Is Active: \(mealPlan.isActive)")
    print("   Created At: \(mealPlan.createdAt)")
    print("   Updated At: \(mealPlan.updatedAt)")
} catch {
    print("❌ Failed to parse MealPlan: \(error)")
    if let decodingError = error as? DecodingError {
        print("   Decoding error details: \(decodingError)")
    }
}

// Test the paginated response format
let paginatedJSON = """
{
    "links": {"next": null, "previous": null},
    "count": 2,
    "total_pages": 1,
    "current_page": 1,
    "page_size": 20,
    "results": [
        {
            "id": "39e7f25b-3800-4aba-adee-5b6d4bba8ecc",
            "user_id": "3ca67ae7-2d91-479c-940b-e868085d5710",
            "name": "猫猫",
            "description": "",
            "week_start_date": "2025-07-21",
            "is_active": false,
            "items_count": 0,
            "created_at": "2025-07-20T08:21:52.001886Z",
            "updated_at": "2025-07-20T18:54:17.594007Z"
        }
    ]
}
""".data(using: .utf8)!

// Define a simple paginated response structure for testing
struct PaginatedResponse<T: Codable>: Codable {
    let results: [T]
    let count: Int
    let totalPages: Int
    let currentPage: Int
    let pageSize: Int
    
    enum CodingKeys: String, CodingKey {
        case results
        case count
        case totalPages = "total_pages"
        case currentPage = "current_page"
        case pageSize = "page_size"
    }
}

do {
    let response = try JSONDecoder().decode(PaginatedResponse<MealPlan>.self, from: paginatedJSON)
    print("✅ Successfully parsed Paginated Response:")
    print("   Count: \(response.count)")
    print("   Results: \(response.results.count) meal plans")
    if let firstPlan = response.results.first {
        print("   First plan: \(firstPlan.name) - \(firstPlan.weekStartDate)")
    }
} catch {
    print("❌ Failed to parse Paginated Response: \(error)")
    if let decodingError = error as? DecodingError {
        print("   Decoding error details: \(decodingError)")
    }
}