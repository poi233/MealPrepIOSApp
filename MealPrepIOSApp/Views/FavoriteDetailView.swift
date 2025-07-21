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
    
    @State private var showingEditView = false
    @State private var showingRemoveAlert = false
    @State private var showingRecipeDetail = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Image
                    AsyncImage(url: URL(string: favorite.recipe.imageUrl ?? "")) { image in
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
                        // Recipe Title and Info
                        VStack(alignment: .leading, spacing: 8) {
                            Text(favorite.recipe.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text(favorite.recipe.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            // Recipe Stats
                            HStack(spacing: 20) {
                                StatView(icon: "clock", value: "\(favorite.recipe.totalTime) min", label: "Total Time")
                                StatView(icon: "star.fill", value: String(format: "%.1f", favorite.recipe.avgRating), label: "Recipe Rating")
                                StatView(icon: "person.2", value: "\(favorite.recipe.nutritionInfo?.servings ?? 4)", label: "Servings")
                            }
                        }
                        
                        Divider()
                        
                        // My Rating and Notes
                        VStack(alignment: .leading, spacing: 12) {
                            Text("My Review")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            // Personal Rating
                            if let rating = favorite.personalRating {
                                HStack(spacing: 8) {
                                    Text("My Rating:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(spacing: 2) {
                                        ForEach(1...5, id: \.self) { star in
                                            Image(systemName: star <= rating ? "star.fill" : "star")
                                                .foregroundColor(star <= rating ? .yellow : .gray)
                                                .font(.subheadline)
                                        }
                                    }
                                    
                                    Text("(\(rating)/5)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                }
                            } else {
                                HStack {
                                    Text("My Rating:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Not rated")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .italic()
                                    
                                    Spacer()
                                }
                            }
                            
                            // Personal Notes
                            if let notes = favorite.personalNotes, !notes.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("My Notes:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text(notes)
                                        .font(.body)
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                            } else {
                                HStack {
                                    Text("My Notes:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text("No notes added")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .italic()
                                    
                                    Spacer()
                                }
                            }
                            
                            // Edit Button
                            Button("Edit Rating & Notes") {
                                showingEditView = true
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Divider()
                        
                        // Recipe Details Preview
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recipe Details")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            // Quick Info
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Prep Time:")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(favorite.recipe.prepTime) min")
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text("Cook Time:")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(favorite.recipe.cookTime) min")
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text("Difficulty:")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(favorite.recipe.difficulty.displayName)
                                        .foregroundColor(difficultyColor)
                                }
                                
                                if let cuisine = favorite.recipe.cuisine {
                                    HStack {
                                        Text("Cuisine:")
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(cuisine)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .font(.subheadline)
                            
                            // View Full Recipe Button
                            Button("View Full Recipe") {
                                showingRecipeDetail = true
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                        }
                        
                        Divider()
                        
                        // Favorite Info
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Favorite Info")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Text("Added to Favorites:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(favorite.addedAt, style: .date)
                                    .font(.subheadline)
                            }
                            
                            HStack {
                                Text("Recipe by:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(favorite.recipe.createdByUser)
                                    .font(.subheadline)
                            }
                        }
                        
                        // Tags
                        if !favorite.recipe.tags.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tags")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(favorite.recipe.tags, id: \.self) { tag in
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
                    Menu {
                        Button("Edit Rating & Notes") {
                            showingEditView = true
                        }
                        
                        Button("View Full Recipe") {
                            showingRecipeDetail = true
                        }
                        
                        Divider()
                        
                        Button("Remove from Favorites", role: .destructive) {
                            showingRemoveAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingEditView) {
                EditFavoriteView(favorite: favorite)
                    .environmentObject(favoritesStore)
            }
            .sheet(isPresented: $showingRecipeDetail) {
                RecipeDetailView(recipe: favorite.recipe)
                    .environmentObject(RecipeStore())
                    .environmentObject(favoritesStore)
            }
            .alert("Remove from Favorites", isPresented: $showingRemoveAlert) {
                Button("Remove", role: .destructive) {
                    removeFavorite()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to remove this recipe from your favorites?")
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
    
    private func removeFavorite() {
        Task {
            let success = await favoritesStore.removeFromFavorites(recipeId: favorite.recipe.id)
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

#Preview {
    let sampleFavorite = Favorite(
        userId: "user1",
        recipe: Recipe(
            id: "recipe1",
            name: "Spaghetti Carbonara",
            description: "Classic Italian pasta dish with eggs, cheese, and pancetta",
            ingredients: [
                Ingredient(name: "Spaghetti", amount: "400", unit: "g", notes: nil),
                Ingredient(name: "Eggs", amount: "4", unit: "large", notes: "room temperature")
            ],
            instructions: "Cook pasta according to package directions...",
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
            createdByUserId: "chef1",
            createdAt: Date(),
            updatedAt: Date()
        ),
        personalRating: 5,
        personalNotes: "This is my absolute favorite pasta recipe! I love how creamy it turns out every time.",
        addedAt: Date()
    )
    
    FavoriteDetailView(favorite: sampleFavorite)
        .environmentObject(FavoritesStore())
}
