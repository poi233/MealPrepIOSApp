//
//  RecipesView.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/20/25.
//

import SwiftUI

struct RecipesView: View {
    @EnvironmentObject var recipeStore: RecipeStore
    @EnvironmentObject var favoritesStore: FavoritesStore
    @State private var showingFilters = false
    @State private var showingCreateRecipe = false
    @State private var selectedRecipe: Recipe?
    @State private var viewMode: RecipeViewMode = .list
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                VStack(spacing: 12) {
                    SearchBar(text: $recipeStore.searchQuery)
                    
                    // Quick Filter Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(
                                title: "My Recipes",
                                isSelected: recipeStore.showMyRecipesOnly,
                                action: {
                                    Task {
                                        if recipeStore.showMyRecipesOnly {
                                            await recipeStore.getAllRecipes()
                                        } else {
                                            await recipeStore.getMyRecipes()
                                        }
                                    }
                                }
                            )
                            
                            FilterChip(
                                title: "Quick (< 30 min)",
                                isSelected: recipeStore.filters.totalTimeMax == 30,
                                action: {
                                    Task {
                                        if recipeStore.filters.totalTimeMax == 30 {
                                            await recipeStore.clearFilters()
                                        } else {
                                            await recipeStore.getQuickRecipes()
                                        }
                                    }
                                }
                            )
                            
                            FilterChip(
                                title: "Highly Rated",
                                isSelected: recipeStore.filters.avgRatingMin == 4.0,
                                action: {
                                    Task {
                                        if recipeStore.filters.avgRatingMin == 4.0 {
                                            await recipeStore.clearFilters()
                                        } else {
                                            await recipeStore.getHighlyRatedRecipes()
                                        }
                                    }
                                }
                            )
                            
                            // Cuisine filters
                            ForEach(["Italian", "Asian", "Mexican", "American"], id: \.self) { cuisine in
                                FilterChip(
                                    title: cuisine,
                                    isSelected: recipeStore.selectedCuisine == cuisine,
                                    action: {
                                        Task {
                                            if recipeStore.selectedCuisine == cuisine {
                                                recipeStore.selectedCuisine = nil
                                                await recipeStore.applyFilters()
                                            } else {
                                                await recipeStore.getRecipesByCuisine(cuisine)
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                // Status Bar
                HStack {
                    Text(recipeStore.statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // View Mode Toggle
                    Picker("View Mode", selection: $viewMode) {
                        Image(systemName: "list.bullet").tag(RecipeViewMode.list)
                        Image(systemName: "square.grid.2x2").tag(RecipeViewMode.grid)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 100)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Content
                if recipeStore.isLoading && recipeStore.recipes.isEmpty {
                    LoadingView(message: "Loading recipes...")
                } else if recipeStore.isEmpty {
                    EmptyStateView(
                        icon: "book.closed",
                        title: "No Recipes Found",
                        message: recipeStore.isSearching ? 
                            "Try adjusting your search or filters" : 
                            "Start by creating your first recipe",
                        actionTitle: recipeStore.isSearching ? "Clear Search" : "Create Recipe",
                        action: {
                            if recipeStore.isSearching {
                                Task {
                                    await recipeStore.clearSearch()
                                }
                            } else {
                                showingCreateRecipe = true
                            }
                        }
                    )
                } else {
                    RecipeListView(
                        recipes: recipeStore.recipes,
                        viewMode: viewMode,
                        isLoadingMore: recipeStore.isLoadingMore,
                        hasMorePages: recipeStore.hasMorePages,
                        onRecipeTap: { recipe in
                            selectedRecipe = recipe
                        },
                        onLoadMore: {
                            Task {
                                await recipeStore.loadMoreRecipes()
                            }
                        }
                    )
                }
            }
            .navigationTitle("Recipes")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Filters") {
                        showingFilters = true
                    }
                    .foregroundColor(recipeStore.hasFilters ? .accentColor : .primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateRecipe = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                Task {
                    await recipeStore.refreshRecipes()
                }
            }
            .sheet(isPresented: $showingFilters) {
                RecipeFiltersView()
                    .environmentObject(recipeStore)
            }
            .sheet(isPresented: $showingCreateRecipe) {
                CreateRecipeView()
                    .environmentObject(recipeStore)
            }
            .sheet(item: $selectedRecipe) { recipe in
                RecipeDetailView(recipe: recipe)
                    .environmentObject(recipeStore)
                    .environmentObject(favoritesStore)
            }
            .task {
                if recipeStore.recipes.isEmpty {
                    await recipeStore.loadRecipes()
                }
            }
            .alert("Error", isPresented: .constant(recipeStore.errorMessage != nil)) {
                Button("OK") {
                    recipeStore.clearError()
                }
            } message: {
                Text(recipeStore.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Supporting Views

enum RecipeViewMode {
    case list, grid
}

// SearchBar and FilterChip are now in SharedComponents.swift

struct RecipeListView: View {
    let recipes: [Recipe]
    let viewMode: RecipeViewMode
    let isLoadingMore: Bool
    let hasMorePages: Bool
    let onRecipeTap: (Recipe) -> Void
    let onLoadMore: () -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewMode == .list {
                    ForEach(recipes) { recipe in
                        RecipeCard(recipe: recipe, style: .standard)
                            .onTapGesture {
                                onRecipeTap(recipe)
                            }
                    }
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(recipes) { recipe in
                            RecipeCard(recipe: recipe, style: .compact)
                                .onTapGesture {
                                    onRecipeTap(recipe)
                                }
                        }
                    }
                }
                
                // Load More Indicator
                if hasMorePages {
                    if isLoadingMore {
                        ProgressView()
                            .padding()
                    } else {
                        Button("Load More") {
                            onLoadMore()
                        }
                        .padding()
                        .onAppear {
                            onLoadMore()
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct RecipeCard: View {
    let recipe: Recipe
    let style: RecipeCardStyle
    @EnvironmentObject var favoritesStore: FavoritesStore
    @State private var isFavorite = false
    
    enum RecipeCardStyle {
        case standard, compact, featured
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Recipe Image
            AsyncImage(url: URL(string: recipe.imageUrl ?? "")) { image in
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
            .frame(height: imageHeight)
            .clipped()
            .cornerRadius(8)
            .overlay(
                // Favorite Button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: toggleFavorite) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(isFavorite ? .red : .white)
                                .font(.title2)
                                .shadow(radius: 2)
                        }
                    }
                    Spacer()
                }
                .padding(8)
            )
            
            // Recipe Info
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(style == .compact ? .subheadline : .headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                if style != .compact {
                    Text(recipe.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Recipe Stats
                HStack(spacing: 12) {
                    Label("\(recipe.totalTime) min", systemImage: "clock")
                    
                    if style != .compact {
                        Label("\(recipe.avgRating, specifier: "%.1f")", systemImage: "star.fill")
                            .foregroundColor(.yellow)
                    }
                    
                    Spacer()
                    
                    Text(recipe.difficulty.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(difficultyColor.opacity(0.2))
                        .foregroundColor(difficultyColor)
                        .cornerRadius(4)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                // Tags
                if !recipe.tags.isEmpty && style != .compact {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(recipe.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .task {
            await checkFavoriteStatus()
        }
    }
    
    private var imageHeight: CGFloat {
        switch style {
        case .standard: return 150
        case .compact: return 120
        case .featured: return 200
        }
    }
    
    private var difficultyColor: Color {
        switch recipe.difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
    
    private func toggleFavorite() {
        Task {
            do {
                let newStatus = try await favoritesStore.toggleFavorite(recipeId: recipe.id)
                await MainActor.run {
                    isFavorite = newStatus
                }
            } catch {
                print("Failed to toggle favorite: \(error)")
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
}

// LoadingView and EmptyStateView are now in SharedComponents.swift

#Preview {
    RecipesView()
        .environmentObject(RecipeStore())
        .environmentObject(FavoritesStore())
}