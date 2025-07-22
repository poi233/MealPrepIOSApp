//
//  RecipeFormModels.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/21/25.
//

import SwiftUI

// MARK: - Recipe Form Models

struct IngredientInput {
    var name = ""
    var amount = ""
    var unit = ""
    var notes: String? = nil
    
    init(name: String = "", amount: String = "", unit: String = "", notes: String? = nil) {
        self.name = name
        self.amount = amount
        self.unit = unit
        self.notes = notes
    }
}

struct NutritionInput {
    var calories = ""
    var protein = ""
    var carbohydrates = ""
    var fat = ""
    var fiber = ""
    var sodium = ""
    var sugar = ""
    var servings = 0
    
    init(calories: String = "", protein: String = "", carbohydrates: String = "", fat: String = "", fiber: String = "", sodium: String = "", sugar: String = "", servings: Int = 0) {
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.fiber = fiber
        self.sodium = sodium
        self.sugar = sugar
        self.servings = servings
    }
    
    var hasValues: Bool {
        !calories.isEmpty || !protein.isEmpty || !carbohydrates.isEmpty ||
        !fat.isEmpty || !fiber.isEmpty || !sodium.isEmpty ||
        !sugar.isEmpty || servings > 0
    }
}

// MARK: - Recipe Form Components

struct IngredientRow: View {
    @Binding var ingredient: IngredientInput
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Ingredient name", text: $ingredient.name)
                
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
            }
            
            HStack {
                TextField("Amount", text: $ingredient.amount)
                    .frame(width: 80)
                
                TextField("Unit", text: $ingredient.unit)
                    .frame(width: 80)
                
                Spacer()
            }
            
            TextField("Notes (optional)", text: Binding(
                get: { ingredient.notes ?? "" },
                set: { ingredient.notes = $0.isEmpty ? nil : $0 }
            ))
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct NutritionInfoView: View {
    @Binding var nutritionInfo: NutritionInput
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Calories", text: $nutritionInfo.calories)
                    .keyboardType(.numberPad)
                TextField("Protein (g)", text: $nutritionInfo.protein)
                    .keyboardType(.decimalPad)
            }
            
            HStack {
                TextField("Carbs (g)", text: $nutritionInfo.carbohydrates)
                    .keyboardType(.decimalPad)
                TextField("Fat (g)", text: $nutritionInfo.fat)
                    .keyboardType(.decimalPad)
            }
            
            HStack {
                TextField("Fiber (g)", text: $nutritionInfo.fiber)
                    .keyboardType(.decimalPad)
                TextField("Sodium (mg)", text: $nutritionInfo.sodium)
                    .keyboardType(.decimalPad)
            }
            
            HStack {
                TextField("Sugar (g)", text: $nutritionInfo.sugar)
                    .keyboardType(.decimalPad)
                
                Stepper("Servings: \(nutritionInfo.servings)", value: $nutritionInfo.servings, in: 0...20)
            }
        }
    }
}