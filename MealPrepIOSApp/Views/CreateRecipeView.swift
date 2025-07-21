//
//  CreateRecipeView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import SwiftUI

struct CreateRecipeView: View {
    @EnvironmentObject var recipeStore: RecipeStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var instructions = ""
    @State private var cuisine = ""
    @State private var prepTime = 15
    @State private var cookTime = 30
    @State private var difficulty: Difficulty = .medium
    @State private var imageUrl = ""
    @State private var tags = ""
    @State private var ingredients: [IngredientInput] = [IngredientInput()]
    @State private var nutritionInfo = NutritionInput()
    
    @State private var showingImagePicker = false
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Recipe Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    HStack {
                        Text("Cuisine")
                        Spacer()
                        TextField("e.g., Italian", text: $cuisine)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Timing & Difficulty") {
                    HStack {
                        Text("Prep Time")
                        Spacer()
                        Stepper("\(prepTime) min", value: $prepTime, in: 1...300, step: 5)
                    }
                    
                    HStack {
                        Text("Cook Time")
                        Spacer()
                        Stepper("\(cookTime) min", value: $cookTime, in: 1...480, step: 5)
                    }
                    
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficulty.allCases, id: \.self) { difficulty in
                            Text(difficulty.displayName).tag(difficulty)
                        }
                    }
                }
                
                Section("Ingredients") {
                    ForEach(ingredients.indices, id: \.self) { index in
                        IngredientRow(ingredient: $ingredients[index]) {
                            if ingredients.count > 1 {
                                ingredients.remove(at: index)
                            }
                        }
                    }
                    
                    Button("Add Ingredient") {
                        ingredients.append(IngredientInput())
                    }
                    .foregroundColor(.accentColor)
                }
                
                Section("Instructions") {
                    TextField("Step-by-step instructions", text: $instructions, axis: .vertical)
                        .lineLimit(5...15)
                }
                
                Section("Additional Details") {
                    TextField("Image URL (optional)", text: $imageUrl)
                    TextField("Tags (comma separated)", text: $tags)
                        .textInputAutocapitalization(.never)
                }
                
                Section("Nutrition Information (Optional)") {
                    NutritionInfoView(nutritionInfo: $nutritionInfo)
                }
            }
            .navigationTitle("Create Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createRecipe()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid || isCreating)
                }
            }
            .disabled(isCreating)
        }
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        ingredients.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    private func createRecipe() {
        isCreating = true
        
        let validIngredients = ingredients.compactMap { ingredient -> Ingredient? in
            let trimmedName = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return nil }
            
            return Ingredient(
                name: trimmedName,
                amount: ingredient.amount.trimmingCharacters(in: .whitespacesAndNewlines),
                unit: ingredient.unit.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: ingredient.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        
        let tagArray = tags.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let nutrition = nutritionInfo.hasValues ? NutritionInfo(
            calories: nutritionInfo.calories.isEmpty ? nil : nutritionInfo.calories,
            protein: nutritionInfo.protein.isEmpty ? nil : nutritionInfo.protein,
            carbohydrates: nutritionInfo.carbohydrates.isEmpty ? nil : nutritionInfo.carbohydrates,
            fat: nutritionInfo.fat.isEmpty ? nil : nutritionInfo.fat,
            fiber: nutritionInfo.fiber.isEmpty ? nil : nutritionInfo.fiber,
            sodium: nutritionInfo.sodium.isEmpty ? nil : nutritionInfo.sodium,
            sugar: nutritionInfo.sugar.isEmpty ? nil : nutritionInfo.sugar,
            servings: nutritionInfo.servings > 0 ? nutritionInfo.servings : nil
        ) : nil
        
        let recipe = CreateRecipeRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            ingredients: validIngredients,
            instructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines),
            nutritionInfo: nutrition,
            cuisine: cuisine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : cuisine.trimmingCharacters(in: .whitespacesAndNewlines),
            prepTime: prepTime,
            cookTime: cookTime,
            difficulty: difficulty,
            imageUrl: imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : imageUrl.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tagArray
        )
        
        Task {
            let success = await recipeStore.createRecipe(recipe)
            
            await MainActor.run {
                isCreating = false
                
                if success {
                    dismiss()
                } else {
                }
            }
        }
    }
}

// MARK: - Supporting Views and Models

struct IngredientInput {
    var name = ""
    var amount = ""
    var unit = ""
    var notes: String? = nil
}

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

struct NutritionInput {
    var calories = ""
    var protein = ""
    var carbohydrates = ""
    var fat = ""
    var fiber = ""
    var sodium = ""
    var sugar = ""
    var servings = 0
    
    var hasValues: Bool {
        !calories.isEmpty || !protein.isEmpty || !carbohydrates.isEmpty ||
        !fat.isEmpty || !fiber.isEmpty || !sodium.isEmpty ||
        !sugar.isEmpty || servings > 0
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

#Preview {
    CreateRecipeView()
        .environmentObject(RecipeStore())
}