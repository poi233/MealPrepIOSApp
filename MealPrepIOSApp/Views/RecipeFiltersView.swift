//
//  RecipeFiltersView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import SwiftUI

struct RecipeFiltersView: View {
    @EnvironmentObject var recipeStore: RecipeStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCuisine: String?
    @State private var selectedDifficulty: Difficulty?
    @State private var selectedMealType: MealType?
    @State private var maxPrepTime: Double = 120
    @State private var maxCookTime: Double = 180
    @State private var minRating: Double = 0
    @State private var showMyRecipesOnly: Bool = false
    
    private let cuisines = ["Italian", "Asian", "Mexican", "American", "French", "Indian", "Mediterranean", "Thai", "Japanese", "Chinese"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Cuisine") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(cuisines, id: \.self) { cuisine in
                                FilterButton(
                                    title: cuisine,
                                    isSelected: selectedCuisine == cuisine
                                ) {
                                    selectedCuisine = selectedCuisine == cuisine ? nil : cuisine
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Section("Difficulty") {
                    HStack(spacing: 12) {
                        ForEach(Difficulty.allCases, id: \.self) { difficulty in
                            FilterButton(
                                title: difficulty.displayName,
                                isSelected: selectedDifficulty == difficulty
                            ) {
                                selectedDifficulty = selectedDifficulty == difficulty ? nil : difficulty
                            }
                        }
                        Spacer()
                    }
                }
                
                Section("Meal Type") {
                    HStack(spacing: 12) {
                        ForEach(MealType.allCases, id: \.self) { mealType in
                            FilterButton(
                                title: mealType.displayName,
                                isSelected: selectedMealType == mealType
                            ) {
                                selectedMealType = selectedMealType == mealType ? nil : mealType
                            }
                        }
                        Spacer()
                    }
                }
                
                Section("Time Limits") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Max Prep Time: \(Int(maxPrepTime)) minutes")
                                .font(.subheadline)
                            Slider(value: $maxPrepTime, in: 5...120, step: 5)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Max Cook Time: \(Int(maxCookTime)) minutes")
                                .font(.subheadline)
                            Slider(value: $maxCookTime, in: 5...180, step: 5)
                        }
                    }
                }
                
                Section("Rating") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Minimum Rating: \(minRating, specifier: "%.1f") stars")
                            .font(.subheadline)
                        Slider(value: $minRating, in: 0...5, step: 0.5)
                    }
                }
                
                Section("Other") {
                    Toggle("My Recipes Only", isOn: $showMyRecipesOnly)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        clearAllFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyFilters()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadCurrentFilters()
            }
        }
    }
    
    private func loadCurrentFilters() {
        selectedCuisine = recipeStore.selectedCuisine
        selectedDifficulty = recipeStore.selectedDifficulty
        selectedMealType = recipeStore.selectedMealType
        showMyRecipesOnly = recipeStore.showMyRecipesOnly
        
        maxPrepTime = Double(recipeStore.filters.prepTimeMax ?? 120)
        maxCookTime = Double(recipeStore.filters.cookTimeMax ?? 180)
        minRating = recipeStore.filters.avgRatingMin ?? 0
    }
    
    private func applyFilters() {
        recipeStore.selectedCuisine = selectedCuisine
        recipeStore.selectedDifficulty = selectedDifficulty
        recipeStore.selectedMealType = selectedMealType
        recipeStore.showMyRecipesOnly = showMyRecipesOnly
        
        recipeStore.filters = RecipeFilters(
            search: recipeStore.searchQuery.isEmpty ? nil : recipeStore.searchQuery,
            cuisine: selectedCuisine,
            difficulty: selectedDifficulty,
            prepTimeMax: maxPrepTime < 120 ? Int(maxPrepTime) : nil,
            cookTimeMax: maxCookTime < 180 ? Int(maxCookTime) : nil,
            totalTimeMax: nil,
            avgRatingMin: minRating > 0 ? minRating : nil,
            tags: nil,
            mealType: selectedMealType,
            myRecipes: showMyRecipesOnly
        )
        
        Task {
            await recipeStore.applyFilters()
        }
    }
    
    private func clearAllFilters() {
        selectedCuisine = nil
        selectedDifficulty = nil
        selectedMealType = nil
        showMyRecipesOnly = false
        maxPrepTime = 120
        maxCookTime = 180
        minRating = 0
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.primaryGreen : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    RecipeFiltersView()
        .environmentObject(RecipeStore())
}