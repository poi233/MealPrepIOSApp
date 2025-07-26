//
//  ManualCreateRecipeView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/21/25.
//

import SwiftUI

struct ManualCreateRecipeView: View {
    @EnvironmentObject var recipeStore: RecipeStore
    @Environment(\.dismiss) private var dismiss
    
    // Manual recipe form data
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
                        ForEach(Difficulty.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
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
                    .foregroundColor(.primaryGreen)
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
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Manual Recipe")
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
        errorMessage = nil
        
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
        
        let finalImageUrl = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("[DEBUG] ManualCreateRecipeView - Raw imageUrl: '\(imageUrl)'")
        print("[DEBUG] ManualCreateRecipeView - Final imageUrl after trimming: '\(finalImageUrl ?? "nil")'")
        
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
            imageUrl: finalImageUrl,
            tags: tagArray
        )
        
        print("[DEBUG] ManualCreateRecipeView - CreateRecipeRequest imageUrl: '\(recipe.imageUrl ?? "nil")'")
        
        Task {
            print("[DEBUG] ManualCreateRecipeView - About to call recipeStore.createRecipe")
            let success = await recipeStore.createRecipe(recipe)
            
            await MainActor.run {
                isCreating = false
                
                if success {
                    dismiss()
                } else {
                    errorMessage = "Failed to create recipe. Please try again."
                }
            }
        }
    }
}

#Preview {
    ManualCreateRecipeView()
        .environmentObject(RecipeStore())
}