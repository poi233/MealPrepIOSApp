import Foundation

// Test data that matches the actual API response format from the error
let testPaginatedRecipeJSON = """
{
    "links": {
        "next": null,
        "previous": null
    },
    "count": 10,
    "total_pages": 1,
    "current_page": 1,
    "page_size": 20,
    "results": [
        {
            "id": "6cd9f11a-dac0-4ccb-b5f2-d2eabd1b0a40",
            "created_by_user": "Miao",
            "created_by_user_id": "7fc8535b-e473-4944-9b70-8a6ab04f5c4e",
            "name": "猪脊骨汤",
            "description": "Delicious 猪脊骨汤 recipe",
            "ingredients": [
                {
                    "name": "猪脊骨 1000克，斩成大块",
                    "amount": 1,
                    "unit": "piece",
                    "notes": ""
                }
            ],
            "instructions": "1. **猪脊骨冷水下锅**，加入姜片和料酒。",
            "nutrition_info": {
                "fat": 15.0,
                "carbs": 30.0,
                "protein": 25.0,
                "calories": 350.0
            },
            "cuisine": "International",
            "prep_time": 15,
            "cook_time": 30,
            "total_time": 45,
            "difficulty": "medium",
            "avg_rating": "0.00",
            "rating_count": 0,
            "image_url": "",
            "tags": ["medium"],
            "created_at": "2025-07-21T00:22:08.661623Z",
            "updated_at": "2025-07-21T00:22:08.661639Z"
        }
    ]
}
"""

// Test individual recipe decoding
let testRecipeJSON = """
{
    "id": "6cd9f11a-dac0-4ccb-b5f2-d2eabd1b0a40",
    "created_by_user": "Miao",
    "created_by_user_id": "7fc8535b-e473-4944-9b70-8a6ab04f5c4e",
    "name": "猪脊骨汤",
    "description": "Delicious 猪脊骨汤 recipe",
    "ingredients": [
        {
            "name": "猪脊骨 1000克，斩成大块",
            "amount": 1,
            "unit": "piece",
            "notes": ""
        }
    ],
    "instructions": "1. **猪脊骨冷水下锅**，加入姜片和料酒。",
    "nutrition_info": {
        "fat": 15.0,
        "carbs": 30.0,
        "protein": 25.0,
        "calories": 350.0
    },
    "cuisine": "International",
    "prep_time": 15,
    "cook_time": 30,
    "total_time": 45,
    "difficulty": "medium",
    "avg_rating": "0.00",
    "rating_count": 0,
    "image_url": "",
    "tags": ["medium"],
    "created_at": "2025-07-21T00:22:08.661623Z",
    "updated_at": "2025-07-21T00:22:08.661639Z"
}
"""

// Test the individual recipe decoding
func testRecipeDecoding() {
    print("🧪 Testing individual Recipe decoding...")
    let jsonData = testRecipeJSON.data(using: .utf8)!
    
    do {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let recipe = try decoder.decode(Recipe.self, from: jsonData)
        
        print("✅ Recipe decoded successfully!")
        print("Name: \(recipe.name)")
        print("Calories: \(recipe.nutritionInfo?.calories ?? "nil")")
        print("Protein: \(recipe.nutritionInfo?.protein ?? "nil")")
        print("Fat: \(recipe.nutritionInfo?.fat ?? "nil")")
        print("Carbs: \(recipe.nutritionInfo?.carbohydrates ?? "nil")")
        print("Avg Rating: \(recipe.avgRating)")
        print("Ingredient Amount: \(recipe.ingredients.first?.amount ?? "nil")")
        
    } catch {
        print("❌ Recipe decoding failed: \(error)")
        if let decodingError = error as? DecodingError {
            print("Decoding error details: \(decodingError)")
        }
    }
}

// Test the paginated response decoding (this was the original failing case)
func testPaginatedRecipeDecoding() {
    print("\n🧪 Testing PaginatedResponse<Recipe> decoding...")
    let jsonData = testPaginatedRecipeJSON.data(using: .utf8)!
    
    do {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let paginatedResponse = try decoder.decode(PaginatedResponse<Recipe>.self, from: jsonData)
        
        print("✅ PaginatedResponse<Recipe> decoded successfully!")
        print("Count: \(paginatedResponse.count)")
        print("Total Pages: \(paginatedResponse.totalPages)")
        print("Current Page: \(paginatedResponse.currentPage)")
        print("Results count: \(paginatedResponse.results.count)")
        
        if let firstRecipe = paginatedResponse.results.first {
            print("First recipe name: \(firstRecipe.name)")
            print("First recipe calories: \(firstRecipe.nutritionInfo?.calories ?? "nil")")
            print("First recipe avg rating: \(firstRecipe.avgRating)")
        }
        
    } catch {
        print("❌ PaginatedResponse<Recipe> decoding failed: \(error)")
        if let decodingError = error as? DecodingError {
            print("Decoding error details: \(decodingError)")
        }
    }
}

// Run both tests
testRecipeDecoding()
testPaginatedRecipeDecoding()