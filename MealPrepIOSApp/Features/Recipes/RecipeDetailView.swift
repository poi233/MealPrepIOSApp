//
//  RecipeDetailView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    let isFromMealPlan: Bool // New parameter to track navigation context
    @EnvironmentObject var recipeStore: RecipeStore
    @EnvironmentObject var favoritesStore: FavoritesStore
    @Environment(\.dismiss) private var dismiss

    @State private var isFavorite = false

    var body: some View {
        mainContent
    }

    private var mainContent: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Image
                    AsyncImage(url: URL(string: recipe.imageUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        DefaultRecipeImageView_Warm(width: 300, height: 250)
                    }
                    .frame(height: 250)
                    .clipped()

                    VStack(alignment: .leading, spacing: 16) {
                        // Title and Basic Info
                        VStack(alignment: .leading, spacing: 8) {
                            Text(recipe.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)

                            MarkdownText(recipe.description, font: .body)
                                .foregroundColor(.secondary)

                            // Recipe Stats
                            HStack(spacing: 20) {
                                StatView(icon: "clock", value: "\(recipe.totalTime) min", label: "Total Time")
                                StatView(icon: "star.fill", value: String(format: "%.1f", recipe.avgRating), label: "Rating")
                                StatView(icon: "flame", value: recipe.nutritionInfo?.calories ?? "N/A", label: "Calories")
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
                                                .background(Color.primaryGreen.opacity(0.1))
                                                .foregroundColor(.primaryGreen)
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

                        // Ingredients
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ingredients")
                                .font(.headline)

                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(recipe.ingredients, id: \.id) { ingredient in
                                    IngredientView(ingredient: ingredient)
                                }
                            }
                        }

                        Divider()

                        // Instructions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Instructions")
                                .font(.headline)

                            ForEach(Array(instructionLines.enumerated()), id: \.offset) { index, instruction in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primaryGreen)
                                        .frame(minWidth: 20, alignment: .leading)

                                    Text(instruction)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }
                                .padding(.bottom, 4)
                            }
                        }

                        // Nutrition Information
                        if let nutrition = recipe.nutritionInfo {
                            Divider()

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Nutrition Information")
                                    .font(.headline)

                                NutritionView(nutrition: nutrition)
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
                toolbarContent
            }
            .onAppear {
                // Use cached favorite status instead of making API call
                checkCachedFavoriteStatus()
            }
    }

    private var difficultyColor: Color {
        switch recipe.difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }

    private var instructionLines: [String] {
        // Instructions are now stored as an array, so we can use them directly
        return recipe.instructions.map { instruction in
            // Remove existing numbering if present (e.g., "1. " or "1) ")
            let trimmed = instruction.replacingOccurrences(of: "^\\d+[.)\\s]+", with: "", options: .regularExpression)
            return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Done") {
                dismiss()
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            // Favorite Button
            Button(action: toggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(isFavorite ? .red : .primary)
            }
        }

        // Edit and Delete functionality removed temporarily to fix build issues
        // TODO: Restore conditional edit/delete based on isFromMealPlan
    }





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
                print("Failed to toggle favorite from heart button: \(error)")
            }
        }
    }

    private func checkCachedFavoriteStatus() {
        // Use the cached favorite status from FavoritesStore to avoid API call
        isFavorite = favoritesStore.isFavorite(recipeId: recipe.id)
        print("📖 [RecipeDetailView] Using cached favorite status for recipe \(recipe.id): \(isFavorite)")
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



}

// MARK: - Supporting Views
// StatView is now in SharedComponents.swift

struct IngredientView: View {
    let ingredient: Ingredient

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if !ingredient.amount.isEmpty {
                        Text(ingredient.amount)
                            .fontWeight(.medium)

                        if !ingredient.unit.isEmpty {
                            Text(ingredient.unit)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text(ingredient.name)
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
}

struct NutritionView: View {
    let nutrition: NutritionInfo

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            if let calories = nutrition.calories {
                NutritionItem(label: "Calories", value: calories, unit: "")
            }

            if let protein = nutrition.protein {
                NutritionItem(label: "Protein", value: protein, unit: "g")
            }

            if let carbs = nutrition.carbohydrates {
                NutritionItem(label: "Carbs", value: carbs, unit: "g")
            }

            if let fat = nutrition.fat {
                NutritionItem(label: "Fat", value: fat, unit: "g")
            }

            if let fiber = nutrition.fiber {
                NutritionItem(label: "Fiber", value: fiber, unit: "g")
            }

            if let sodium = nutrition.sodium {
                NutritionItem(label: "Sodium", value: sodium, unit: "mg")
            }
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

// EditRecipeView is now implemented in its own file

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
        instructions: [
            "Cook pasta according to package directions.",
            "While pasta cooks, whisk eggs with cheese.",
            "Cook pancetta until crispy.",
            "Combine hot pasta with egg mixture and pancetta.",
            "Serve immediately."
        ],
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

    RecipeDetailView(recipe: sampleRecipe, isFromMealPlan: false)
        .environmentObject(RecipeStore())
        .environmentObject(FavoritesStore())
}
