//
//  RecipeDetailView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @EnvironmentObject var recipeStore: RecipeStore
    @EnvironmentObject var favoritesStore: FavoritesStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var isFavorite = false
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var servingMultiplier: Double = 1.0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Image
                    AsyncImage(url: URL(string: recipe.imageUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                            )
                    }
                    .frame(height: 250)
                    .clipped()
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Title and Basic Info
                        VStack(alignment: .leading, spacing: 8) {
                            Text(recipe.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text(recipe.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            // Recipe Stats
                            HStack(spacing: 20) {
                                StatView(icon: "clock", value: "\(recipe.totalTime) min", label: "Total Time")
                                StatView(icon: "star.fill", value: String(format: "%.1f", recipe.avgRating), label: "Rating")
                                StatView(icon: "person.2", value: "\(recipe.nutritionInfo?.servings ?? 4)", label: "Servings")
                            }
                            
                            // Tags
                            if !recipe.tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(recipe.tags, id: \.self) { tag in
                                            Text(tag)
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.accentColor.opacity(0.1))
                                                .foregroundColor(.accentColor)
                                                .cornerRadius(8)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Timing and Difficulty
                        HStack(spacing: 30) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Prep Time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(recipe.prepTime) min")
                                    .font(.headline)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cook Time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(recipe.cookTime) min")
                                    .font(.headline)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Difficulty")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(recipe.difficulty.displayName)
                                    .font(.headline)
                                    .foregroundColor(difficultyColor)
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Serving Size Adjuster
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Servings")
                                .font(.headline)
                            
                            HStack {
                                Button(action: { adjustServings(-0.5) }) {
                                    Image(systemName: "minus.circle")
                                        .font(.title2)
                                }
                                .disabled(servingMultiplier <= 0.5)
                                
                                Text("\(Int(servingMultiplier * Double(recipe.nutritionInfo?.servings ?? 4)))")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .frame(minWidth: 40)
                                
                                Button(action: { adjustServings(0.5) }) {
                                    Image(systemName: "plus.circle")
                                        .font(.title2)
                                }
                                .disabled(servingMultiplier >= 4.0)
                                
                                Spacer()
                                
                                if servingMultiplier != 1.0 {
                                    Button("Reset") {
                                        servingMultiplier = 1.0
                                    }
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Ingredients
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ingredients")
                                .font(.headline)
                            
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(recipe.ingredients, id: \.id) { ingredient in
                                    IngredientView(ingredient: ingredient, multiplier: servingMultiplier)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Instructions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Instructions")
                                .font(.headline)
                            
                            Text(recipe.instructions)
                                .font(.body)
                                .lineSpacing(4)
                        }
                        
                        // Nutrition Information
                        if let nutrition = recipe.nutritionInfo {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Nutrition Information")
                                    .font(.headline)
                                
                                NutritionView(nutrition: nutrition, multiplier: servingMultiplier)
                            }
                        }
                        
                        // Recipe Meta
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recipe by \(recipe.createdByUser)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Created \(recipe.createdAt, style: .date)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if recipe.cuisine != nil {
                                Text("Cuisine: \(recipe.cuisine!)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: toggleFavorite) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(isFavorite ? .red : .primary)
                        }
                        
                        Menu {
                            Button("Share Recipe") {
                                showingShareSheet = true
                            }
                            
                            if canEditRecipe {
                                Button("Edit Recipe") {
                                    showingEditView = true
                                }
                                
                                Button("Delete Recipe", role: .destructive) {
                                    showingDeleteAlert = true
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .task {
                await checkFavoriteStatus()
            }
            .sheet(isPresented: $showingEditView) {
                EditRecipeView(recipe: recipe)
                    .environmentObject(recipeStore)
            }
            .alert("Delete Recipe", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteRecipe()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this recipe? This action cannot be undone.")
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var difficultyColor: Color {
        switch recipe.difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
    
    private var canEditRecipe: Bool {
        // In a real app, check if current user is the recipe creator
        // For now, assume all recipes can be edited
        true
    }
    
    private func adjustServings(_ change: Double) {
        let newMultiplier = servingMultiplier + change
        servingMultiplier = max(0.5, min(4.0, newMultiplier))
    }
    
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    private func toggleFavorite() {
        Task {
            do {
                print("Heart button tapped for recipe: \(recipe.id)")
                // Don't pass a rating when toggling from the heart button
                // This avoids validation errors since we're not asking the user for a rating
                let newStatus = try await favoritesStore.toggleFavorite(recipeId: recipe.id, rating: nil, notes: nil)
                await MainActor.run {
                    isFavorite = newStatus
                    print("Heart button toggle successful. New status: \(newStatus)")
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
                print("Failed to toggle favorite from heart button: \(error)")
            }
        }
    }
    
    private func checkFavoriteStatus() async {
        do {
            let status = try await favoritesStore.checkFavoriteStatus(recipeId: recipe.id)
            await MainActor.run {
                isFavorite = status.isFavorite
            }
        } catch {
            // Ignore error, default to not favorite
        }
    }
    
    private func deleteRecipe() {
        Task {
            let success = await recipeStore.deleteRecipe(id: recipe.id)
            if success {
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Supporting Views
// StatView is now in SharedComponents.swift

struct IngredientView: View {
    let ingredient: Ingredient
    let multiplier: Double
    @State private var isChecked = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: { isChecked.toggle() }) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isChecked ? .accentColor : .secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if !ingredient.amount.isEmpty {
                        Text(adjustedAmount)
                            .fontWeight(.medium)
                        
                        if !ingredient.unit.isEmpty {
                            Text(ingredient.unit)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(ingredient.name)
                        .strikethrough(isChecked)
                        .foregroundColor(isChecked ? .secondary : .primary)
                }
                
                if let notes = ingredient.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Spacer()
        }
    }
    
    private var adjustedAmount: String {
        guard let amount = Double(ingredient.amount) else {
            return ingredient.amount
        }
        
        let adjusted = amount * multiplier
        
        // Format nicely
        if adjusted == floor(adjusted) {
            return String(format: "%.0f", adjusted)
        } else if adjusted * 2 == floor(adjusted * 2) {
            return String(format: "%.1f", adjusted)
        } else {
            return String(format: "%.2f", adjusted)
        }
    }
}

struct NutritionView: View {
    let nutrition: NutritionInfo
    let multiplier: Double
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            if let calories = nutrition.calories {
                NutritionItem(label: "Calories", value: adjustValue(calories), unit: "")
            }
            
            if let protein = nutrition.protein {
                NutritionItem(label: "Protein", value: adjustValue(protein), unit: "g")
            }
            
            if let carbs = nutrition.carbohydrates {
                NutritionItem(label: "Carbs", value: adjustValue(carbs), unit: "g")
            }
            
            if let fat = nutrition.fat {
                NutritionItem(label: "Fat", value: adjustValue(fat), unit: "g")
            }
            
            if let fiber = nutrition.fiber {
                NutritionItem(label: "Fiber", value: adjustValue(fiber), unit: "g")
            }
            
            if let sodium = nutrition.sodium {
                NutritionItem(label: "Sodium", value: adjustValue(sodium), unit: "mg")
            }
        }
    }
    
    private func adjustValue(_ value: String) -> String {
        guard let numValue = Double(value) else { return value }
        let adjusted = numValue * multiplier
        
        if adjusted == floor(adjusted) {
            return String(format: "%.0f", adjusted)
        } else {
            return String(format: "%.1f", adjusted)
        }
    }
}

struct NutritionItem: View {
    let label: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)\(unit)")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// Placeholder for EditRecipeView
struct EditRecipeView: View {
    let recipe: Recipe
    @EnvironmentObject var recipeStore: RecipeStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Edit Recipe - Coming Soon")
                .navigationTitle("Edit Recipe")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

#Preview {
    let sampleRecipe = Recipe(
        id: "1",
        name: "Spaghetti Carbonara",
        description: "Classic Italian pasta dish with eggs, cheese, and pancetta",
        ingredients: [
            Ingredient(name: "Spaghetti", amount: "400", unit: "g", notes: nil),
            Ingredient(name: "Eggs", amount: "4", unit: "large", notes: "room temperature"),
            Ingredient(name: "Pancetta", amount: "150", unit: "g", notes: "diced")
        ],
        instructions: "1. Cook pasta according to package directions.\n2. While pasta cooks, whisk eggs with cheese.\n3. Cook pancetta until crispy.\n4. Combine hot pasta with egg mixture and pancetta.\n5. Serve immediately.",
        nutritionInfo: NutritionInfo(calories: "520", protein: "22", carbohydrates: "65", fat: "18", fiber: "3", sodium: "890", sugar: "3", servings: 4),
        cuisine: "Italian",
        prepTime: 10,
        cookTime: 15,
        difficulty: .medium,
        avgRating: 4.5,
        ratingCount: 12,
        imageUrl: nil,
        tags: ["pasta", "italian", "quick"],
        createdByUser: "Chef Mario",
        createdByUserId: "user123",
        createdAt: Date(),
        updatedAt: Date()
    )
    
    RecipeDetailView(recipe: sampleRecipe)
        .environmentObject(RecipeStore())
        .environmentObject(FavoritesStore())
}