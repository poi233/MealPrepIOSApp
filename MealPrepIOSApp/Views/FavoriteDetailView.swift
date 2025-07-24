//
//  FavoriteDetailView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import SwiftUI

struct FavoriteDetailView: View {
    let favorite: Favorite
    @EnvironmentObject var favoritesStore: FavoritesStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var servingMultiplier: Double = 1.0
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Image - full width without white space
                AsyncImage(url: URL(string: favorite.recipe.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    DefaultRecipeImageView()
                }
                .frame(height: 250)
                .clipped()
                
                VStack(alignment: .leading, spacing: 16) {
                    // Title and Basic Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(favorite.recipe.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(favorite.recipe.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        // Personal Rating Section (Favorite-specific)
                        if let rating = favorite.personalRating {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("My Rating")
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                                
                                HStack(spacing: 4) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= rating ? "star.fill" : "star")
                                            .foregroundColor(star <= rating ? .yellow : .gray.opacity(0.3))
                                            .font(.title3)
                                    }
                                    
                                    Text("(\(rating)/5)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 4)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.yellow.opacity(0.1))
                                )
                            }
                        }
                        
                        // Personal Notes Section (Favorite-specific)
                        if let notes = favorite.personalNotes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("My Notes")
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                                
                                Text(notes)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .italic()
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Basic Recipe Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recipe Information")
                            .font(.headline)
                        
                        HStack {
                            Text("Prep Time:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(favorite.recipe.prepTime) minutes")
                                .font(.subheadline)
                        }
                        
                        HStack {
                            Text("Cook Time:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(favorite.recipe.cookTime) minutes")
                                .font(.subheadline)
                        }
                        
                        HStack {
                            Text("Total Time:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(favorite.recipe.totalTime) minutes")
                                .font(.subheadline)
                        }
                        
                        HStack {
                            Text("Difficulty:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(favorite.recipe.difficulty.displayName)
                                .font(.subheadline)
                                .foregroundColor(difficultyColor)
                        }
                        
                        if let servings = favorite.recipe.nutritionInfo?.servings {
                            HStack {
                                Text("Servings:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(servings)")
                                    .font(.subheadline)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Ingredients
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ingredients")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(favorite.recipe.ingredients, id: \.id) { ingredient in
                                HStack(alignment: .top, spacing: 12) {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.2))
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 6)
                                    
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
                    }
                    
                    Divider()
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Instructions")
                            .font(.headline)
                        
                        Text(favorite.recipe.instructions)
                            .font(.body)
                            .lineSpacing(4)
                    }
                    
                    // Favorite-specific Meta Information
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Favorite Info")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        
                        HStack {
                            Text("Added to favorites:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(favorite.addedAt, style: .date)
                                .font(.caption)
                        }
                        
                        HStack {
                            Text("Recipe by:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(favorite.recipe.createdByUser)
                                .font(.caption)
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
        }
    }
    
    private var difficultyColor: Color {
        switch favorite.recipe.difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
    
}

#Preview {
    let sampleFavorite = Favorite(
        userId: "user123",
        recipe: Recipe(
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
        ),
        personalRating: 5,
        personalNotes: "My favorite pasta recipe!",
        addedAt: Date()
    )
    
    NavigationView {
        FavoriteDetailView(favorite: sampleFavorite)
            .environmentObject(FavoritesStore())
    }
}
