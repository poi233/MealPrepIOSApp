//
//  ShoppingListService.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 8/3/25.
//  Extracted from MealPlanStore.swift for better separation of concerns.
//

import SwiftUI
import Combine

// MARK: - Shopping List Service
@MainActor
class ShoppingListService: ObservableObject {
    @Published var shoppingList: [ShoppingListItem] = []
    @Published var isLoadingShoppingList = false

    private let mealPlanService = MealPlanService()

    // MARK: - Shopping List Generation

    func generateShoppingList(from weeklyGrid: WeeklyMealGrid) async {
        isLoadingShoppingList = true

        do {
            // Try backend first
            let mealPlan = createMealPlan(from: weeklyGrid)
            let items = try await mealPlanService.generateShoppingList(mealPlan: mealPlan)

            // Enhance items with better categorization
            let enhancedItems = enhanceShoppingListItems(items)
            shoppingList = enhancedItems
            
            print("✅ [ShoppingListService] Generated shopping list with \\(enhancedItems.count) items via backend")
        } catch {
            print("⚠️ [ShoppingListService] Backend failed, using local fallback: \\(error)")
            
            // Local fallback: generate from recipes directly
            let localItems = generateShoppingListLocally(from: weeklyGrid)
            shoppingList = localItems
            
            print("✅ [ShoppingListService] Generated shopping list with \\(localItems.count) items via local fallback")
        }

        isLoadingShoppingList = false
    }

    private func createMealPlan(from weeklyGrid: WeeklyMealGrid) -> MealPlan {
        // Convert weekly grid to meal plan items
        var items: [MealPlanItem] = []

        for (dayIndex, dayMeals) in weeklyGrid.dailyMeals.enumerated() {
            // Add breakfast items
            for recipe in dayMeals.breakfast {
                let item = MealPlanItem(
                    id: nil,
                    mealPlanId: nil,
                    recipe: recipe,
                    recipeId: recipe.id,
                    dayOfWeek: dayIndex,
                    mealType: "breakfast",
                    addedAt: Date()
                )
                items.append(item)
            }

            // Add lunch items
            for recipe in dayMeals.lunch {
                let item = MealPlanItem(
                    id: nil,
                    mealPlanId: nil,
                    recipe: recipe,
                    recipeId: recipe.id,
                    dayOfWeek: dayIndex,
                    mealType: "lunch",
                    addedAt: Date()
                )
                items.append(item)
            }

            // Add dinner items
            for recipe in dayMeals.dinner {
                let item = MealPlanItem(
                    id: nil,
                    mealPlanId: nil,
                    recipe: recipe,
                    recipeId: recipe.id,
                    dayOfWeek: dayIndex,
                    mealType: "dinner",
                    addedAt: Date()
                )
                items.append(item)
            }
        }

        // Create temporary meal plan
        return MealPlan(
            id: UUID().uuidString,
            userId: nil,
            name: "Temporary Shopping List Plan",
            description: "Generated for shopping list",

            isActive: false,
            planDescription: nil,
            analysisText: nil,
            items: items,
            itemsCount: items.count,
            dailyMeals: nil,
            lightweightDailyMeals: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func extractRecipesFromGrid(_ weeklyGrid: WeeklyMealGrid) -> [Recipe] {
        var recipes: [Recipe] = []

        for dayMeals in weeklyGrid.dailyMeals {
            recipes.append(contentsOf: dayMeals.breakfast)
            recipes.append(contentsOf: dayMeals.lunch)
            recipes.append(contentsOf: dayMeals.dinner)
        }

        return recipes
    }

    func clearShoppingList() {
        shoppingList = []
    }

    // MARK: - Shopping List Management

    func toggleShoppingListItem(_ item: ShoppingListItem) {
        if let index = shoppingList.firstIndex(where: { $0.id == item.id }) {
            shoppingList[index].isCompleted.toggle()
        }
    }

    func removeShoppingListItem(_ item: ShoppingListItem) {
        shoppingList.removeAll { $0.id == item.id }
    }

    func addCustomShoppingListItem(name: String, amount: String = "", unit: String = "") {
        let newItem = ShoppingListItem(
            ingredient: name,
            amount: amount,
            unit: unit,
            category: categorizeIngredient(name),
            recipes: []
        )
        shoppingList.append(newItem)
    }

    // MARK: - Local Shopping List Generation
    
    private func generateShoppingListLocally(from weeklyGrid: WeeklyMealGrid) -> [ShoppingListItem] {
        var ingredientMap: [String: ShoppingListItem] = [:]
        
        // Extract all recipes from the weekly grid
        let recipes = extractRecipesFromGrid(weeklyGrid)
        
        // Aggregate ingredients from all recipes
        for recipe in recipes {
            for ingredient in recipe.ingredients {
                let key = ingredient.name.lowercased()
                
                if let existingItem = ingredientMap[key] {
                    // Combine amounts and add recipe to list
                    var recipeNames = existingItem.recipes
                    if !recipeNames.contains(recipe.name) {
                        recipeNames.append(recipe.name)
                    }
                    
                    ingredientMap[key] = ShoppingListItem(
                        ingredient: ingredient.name,
                        amount: combineAmounts(existingItem.amount, ingredient.amount),
                        unit: ingredient.unit,
                        category: categorizeIngredient(ingredient.name),
                        recipes: recipeNames
                    )
                } else {
                    // Create new shopping list item
                    ingredientMap[key] = ShoppingListItem(
                        ingredient: ingredient.name,
                        amount: ingredient.amount,
                        unit: ingredient.unit,
                        category: categorizeIngredient(ingredient.name),
                        recipes: [recipe.name]
                    )
                }
            }
        }
        
        // Convert to sorted array and enhance with categories
        let items = Array(ingredientMap.values).sorted { $0.ingredient < $1.ingredient }
        return enhanceShoppingListItems(items)
    }
    
    private func enhanceShoppingListItems(_ items: [ShoppingListItem]) -> [ShoppingListItem] {
        return items.map { item in
            ShoppingListItem(
                ingredient: item.ingredient,
                amount: item.amount,
                unit: item.unit,
                category: categorizeIngredient(item.ingredient),
                recipes: item.recipes
            )
        }
    }
    
    private func categorizeIngredient(_ ingredient: String) -> String {
        let lowercased = ingredient.lowercased()
        
        // Meat & Poultry
        if lowercased.contains("chicken") || lowercased.contains("beef") || lowercased.contains("pork") ||
           lowercased.contains("turkey") || lowercased.contains("lamb") || lowercased.contains("meat") {
            return "Meat & Poultry"
        }
        
        // Seafood
        if lowercased.contains("fish") || lowercased.contains("salmon") || lowercased.contains("tuna") ||
           lowercased.contains("shrimp") || lowercased.contains("crab") || lowercased.contains("lobster") {
            return "Seafood"
        }
        
        // Dairy & Eggs
        if lowercased.contains("milk") || lowercased.contains("cheese") || lowercased.contains("yogurt") ||
           lowercased.contains("butter") || lowercased.contains("cream") || lowercased.contains("egg") {
            return "Dairy & Eggs"
        }
        
        // Fruits
        if lowercased.contains("apple") || lowercased.contains("banana") || lowercased.contains("orange") ||
           lowercased.contains("berry") || lowercased.contains("grape") || lowercased.contains("lemon") ||
           lowercased.contains("lime") || lowercased.contains("peach") || lowercased.contains("pear") {
            return "Fruits"
        }
        
        // Vegetables
        if lowercased.contains("lettuce") || lowercased.contains("tomato") || lowercased.contains("onion") ||
           lowercased.contains("carrot") || lowercased.contains("potato") || lowercased.contains("pepper") ||
           lowercased.contains("spinach") || lowercased.contains("broccoli") || lowercased.contains("cucumber") {
            return "Vegetables"
        }
        
        // Grains & Bread
        if lowercased.contains("bread") || lowercased.contains("pasta") || lowercased.contains("rice") ||
           lowercased.contains("flour") || lowercased.contains("cereal") || lowercased.contains("oat") ||
           lowercased.contains("quinoa") || lowercased.contains("wheat") {
            return "Grains & Bread"
        }
        
        // Pantry & Spices
        if lowercased.contains("oil") || lowercased.contains("vinegar") || lowercased.contains("salt") ||
           lowercased.contains("pepper") || lowercased.contains("spice") || lowercased.contains("herb") ||
           lowercased.contains("sugar") || lowercased.contains("honey") {
            return "Pantry & Spices"
        }
        
        // Default category
        return "Other"
    }
    
    // Note: extractRecipesFromGrid method is defined above at line 115
    
    private func combineAmounts(_ amount1: String, _ amount2: String) -> String {
        // Try to parse as numbers and add them
        if let num1 = Double(amount1), let num2 = Double(amount2) {
            let combined = num1 + num2
            return combined.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(combined)) : String(format: "%.1f", combined)
        }
        
        // If parsing fails, concatenate with "+"
        if amount1.isEmpty {
            return amount2
        } else if amount2.isEmpty {
            return amount1
        } else {
            return "\(amount1) + \(amount2)"
        }
    }

    // MARK: - Computed Properties

    var completedItems: [ShoppingListItem] {
        shoppingList.filter { $0.isCompleted }
    }

    var pendingItems: [ShoppingListItem] {
        shoppingList.filter { !$0.isCompleted }
    }

    var groupedShoppingList: [String: [ShoppingListItem]] {
        Dictionary(grouping: shoppingList) { item in
            // Group by category if available, otherwise by first letter
            item.category ?? String(item.ingredient.prefix(1).uppercased())
        }
    }

    var totalItemsCount: Int {
        shoppingList.count
    }

    var completedItemsCount: Int {
        completedItems.count
    }

    var completionPercentage: Double {
        guard totalItemsCount > 0 else { return 0 }
        return Double(completedItemsCount) / Double(totalItemsCount)
    }
}