//
//  EditRecipeView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/21/25.
//

import SwiftUI

struct EditRecipeView: View {
    @EnvironmentObject var recipeStore: RecipeStore
    @Environment(\.dismiss) private var dismiss
    
    let recipe: Recipe
    
    // Recipe form data
    @State private var name: String
    @State private var description: String
    @State private var instructions: String
    @State private var cuisine: String
    @State private var prepTime: Int
    @State private var cookTime: Int
    @State private var difficulty: Difficulty
    @State private var imageUrl: String
    @State private var tags: String
    @State private var ingredients: [IngredientInput]
    @State private var nutritionInfo: NutritionInput
    
    @State private var isUpdating = false
    @State private var errorMessage: String?
    
    init(recipe: Recipe) {
        self.recipe = recipe
        
        // Initialize state variables with recipe data
        _name = State(initialValue: recipe.name)
        _description = State(initialValue: recipe.description)
        _instructions = State(initialValue: recipe.instructions.joined(separator: "\n"))
        _cuisine = State(initialValue: recipe.cuisine ?? "")
        _prepTime = State(initialValue: recipe.prepTime)
        _cookTime = State(initialValue: recipe.cookTime)
        _difficulty = State(initialValue: recipe.difficulty)
        _imageUrl = State(initialValue: recipe.imageUrl ?? "")
        _tags = State(initialValue: recipe.tags.joined(separator: ", "))
        
        // Convert ingredients to IngredientInput
        let ingredientInputs = recipe.ingredients.map { ingredient in
            IngredientInput(
                name: ingredient.name,
                amount: ingredient.amount,
                unit: ingredient.unit,
                notes: ingredient.notes
            )
        }
        _ingredients = State(initialValue: ingredientInputs)
        
        // Convert nutrition info to NutritionInput
        let nutrition = recipe.nutritionInfo
        _nutritionInfo = State(initialValue: NutritionInput(
            calories: nutrition?.calories ?? "",
            protein: nutrition?.protein ?? "",
            carbohydrates: nutrition?.carbohydrates ?? "",
            fat: nutrition?.fat ?? "",
            fiber: nutrition?.fiber ?? "",
            sodium: nutrition?.sodium ?? "",
            sugar: nutrition?.sugar ?? "",
            servings: nutrition?.servings ?? 0
        ))
    }
    
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
                        TextField("e.g., Italian, Mexican", text: $cuisine)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Timing & Difficulty") {
                    HStack {
                        Text("Prep Time")
                        Spacer()
                        Stepper("\(prepTime) minutes", value: $prepTime, in: 0...180, step: 5)
                    }
                    
                    HStack {
                        Text("Cook Time")
                        Spacer()
                        Stepper("\(cookTime) minutes", value: $cookTime, in: 0...480, step: 5)
                    }
                    
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficulty.allCases, id: \.self) { level in
                            Text(level.displayName)
                        }
                    }
                }
                
                Section("Ingredients") {
                    ForEach($ingredients) { $ingredient in
                        IngredientRow(
                            ingredient: $ingredient,
                            onDelete: {
                                if let index = ingredients.firstIndex(where: { $0.id == ingredient.id }) {
                                    if ingredients.count > 1 {
                                        ingredients.remove(at: index)
                                    }
                                }
                            }
                        )
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
                
                Section("Nutrition Information") {
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
            .navigationTitle("Edit Recipe")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateRecipe()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid || isUpdating)
                }
            }
            .disabled(isUpdating)
        }
    }
    
    private var isFormValid: Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        ingredients.contains(where: { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }
    
    private func updateRecipe() {
        isUpdating = true
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
        
        let updatedRecipe = CreateRecipeRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            ingredients: validIngredients,
            instructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            nutritionInfo: nutrition,
            cuisine: cuisine.trimmingCharacters(in: .whitespacesAndNewlines),
            prepTime: prepTime,
            cookTime: cookTime,
            difficulty: difficulty,
            imageUrl: imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : imageUrl.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tagArray
        )
        
        Task {
            let success = await recipeStore.updateRecipe(id: recipe.id, recipe: updatedRecipe)
            
            await MainActor.run {
                isUpdating = false
                
                if success {
                    dismiss()
                } else {
                    errorMessage = "Failed to update recipe. Please try again."
                }
            }
        }
    }
}

#Preview {
    // Create a sample recipe for preview
    let sampleRecipe = Recipe(
        id: "1",
        name: "Sample Recipe",
        description: "A delicious sample recipe",
        ingredients: [
            Ingredient(name: "Ingredient 1", amount: "1", unit: "cup", notes: nil),
            Ingredient(name: "Ingredient 2", amount: "2", unit: "tbsp", notes: "chopped")
        ],
        instructions: ["Step one", "Step two", "Enjoy!"],
        nutritionInfo: NutritionInfo(calories: "200", protein: "5g", carbohydrates: "30g", fat: "10g", fiber: "2g", sodium: "200mg", sugar: "5g", servings: 4),
        cuisine: "Italian",
        prepTime: 15,
        cookTime: 30,
        difficulty: .medium,
        avgRating: 4.5,
        ratingCount: 10,
        imageUrl: nil,
        tags: ["quick", "easy"],
        createdByUser: "Test User",
        createdByUserId: "user123",
        createdAt: Date(),
        updatedAt: Date()
    )
    
    NavigationView {
        EditRecipeView(recipe: sampleRecipe)
            .environmentObject(RecipeStore())
    }
}
