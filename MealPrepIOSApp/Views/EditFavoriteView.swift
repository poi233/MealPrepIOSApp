//
//  EditFavoriteView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import SwiftUI

struct EditFavoriteView: View {
    let favorite: Favorite
    @EnvironmentObject var favoritesStore: FavoritesStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var personalRating: Int
    @State private var personalNotes: String
    @State private var isUpdating = false
    
    init(favorite: Favorite) {
        self.favorite = favorite
        self._personalRating = State(initialValue: favorite.personalRating ?? 0)
        self._personalNotes = State(initialValue: favorite.personalNotes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Recipe") {
                    HStack {
                        AsyncImage(url: URL(string: favorite.recipe.imageUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        }
                        .frame(width: 60, height: 60)
                        .clipped()
                        .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(favorite.recipe.name)
                                .font(.headline)
                                .lineLimit(2)
                            
                            Text(favorite.recipe.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                    }
                }
                
                Section("My Rating") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rate this recipe")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 8) {
                            ForEach(0...5, id: \.self) { rating in
                                Button(action: {
                                    personalRating = rating
                                }) {
                                    Image(systemName: rating == 0 ? "xmark.circle" : (rating <= personalRating ? "star.fill" : "star"))
                                        .foregroundColor(rating == 0 ? .red : (rating <= personalRating ? .yellow : .gray))
                                        .font(.title2)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            Spacer()
                            
                            if personalRating > 0 {
                                Text("\(personalRating) star\(personalRating == 1 ? "" : "s")")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("No rating")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("My Notes") {
                    TextField("Add your personal notes about this recipe...", text: $personalNotes, axis: .vertical)
                        .lineLimit(3...8)
                        .textInputAutocapitalization(.sentences)
                }
                
                Section("Favorite Info") {
                    HStack {
                        Text("Added to Favorites")
                        Spacer()
                        Text(favorite.addedAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Recipe Rating")
                        Spacer()
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("\(favorite.recipe.avgRating, specifier: "%.1f")")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Favorite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateFavorite()
                    }
                    .fontWeight(.semibold)
                    .disabled(isUpdating)
                }
            }
            .disabled(isUpdating)
        }
    }
    
    private func updateFavorite() {
        isUpdating = true
        
        let rating = personalRating > 0 ? personalRating : nil
        let notes = personalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNotes = notes.isEmpty ? nil : notes
        
        Task {
            let success = await favoritesStore.updateFavorite(
                favoriteId: favorite.id,
                rating: rating,
                notes: finalNotes
            )
            
            await MainActor.run {
                isUpdating = false
                if success {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    let sampleFavorite = Favorite(
        userId: "user1",
        recipe: Recipe(
            id: "recipe1",
            name: "Spaghetti Carbonara",
            description: "Classic Italian pasta dish",
            ingredients: [],
            instructions: "Cook pasta...",
            nutritionInfo: nil,
            cuisine: "Italian",
            prepTime: 10,
            cookTime: 15,
            difficulty: .medium,
            avgRating: 4.5,
            ratingCount: 12,
            imageUrl: nil,
            tags: ["pasta", "italian"],
            createdByUser: "Chef Mario",
            createdByUserId: "chef1",
            createdAt: Date(),
            updatedAt: Date()
        ),
        personalRating: 5,
        personalNotes: "My favorite pasta recipe!",
        addedAt: Date()
    )
    
    EditFavoriteView(favorite: sampleFavorite)
        .environmentObject(FavoritesStore())
}
