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
            // Create a temporary meal plan from the weekly grid
            let mealPlan = createMealPlan(from: weeklyGrid)
            let items = try await mealPlanService.generateShoppingList(mealPlan: mealPlan)
            
            shoppingList = items
            print("✅ [ShoppingListService] Generated shopping list with \\(items.count) items")
        } catch {
            print("❌ [ShoppingListService] Error generating shopping list: \\(error)")
            shoppingList = []
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
            recipes: [],
            isCompleted: false
        )
        shoppingList.append(newItem)
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
            // Group by ingredient name's first letter for alphabetical grouping
            String(item.ingredient.prefix(1).uppercased())
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