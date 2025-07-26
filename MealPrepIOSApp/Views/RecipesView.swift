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
    @EnvironmentObject var authStore: AuthStore
    @State private var showingFilters = false
    @State private var showingCreateRecipe = false
    @State private var showingManualCreateRecipe = false
    @State private var selectedRecipe: Recipe?
    @State private var viewMode: RecipeViewMode = .list
    @State private var recipeToEdit: Recipe?
    @State private var showingEditRecipe = false
    
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
                        },
                        onEditRecipe: { recipe in
                            recipeToEdit = recipe
                            showingEditRecipe = true
                        },
                        onDeleteRecipe: { recipe in
                            Task {
                                let success = await recipeStore.deleteRecipe(id: recipe.id)
                                if success {
                                    print("Recipe deleted successfully")
                                } else {
                                    print("Failed to delete recipe")
                                }
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
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(recipeStore.hasFilters ? .primaryGreen : .primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(recipeStore.hasFilters ? Color.primaryGreen.opacity(0.1) : Color.clear)
                    )
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingCreateRecipe = true
                        } label: {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("AI Generated Recipe")
                            }
                        }
                        
                        Button {
                            showingManualCreateRecipe = true
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Manual Entry")
                            }
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primaryGreen, .primaryGreen.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
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
                NavigationView {
                    AIRecipeGenerationView()
                        .environmentObject(recipeStore)
                }
            }
            .sheet(isPresented: $showingManualCreateRecipe) {
                NavigationView {
                    ManualCreateRecipeView()
                        .environmentObject(recipeStore)
                }
            }
            .sheet(item: $selectedRecipe) { recipe in
                NavigationView {
                    RecipeDetailView(recipe: recipe, isFromMealPlan: false)
                        .environmentObject(recipeStore)
                        .environmentObject(favoritesStore)
                }
            }
            .sheet(isPresented: $showingEditRecipe) {
                if let recipe = recipeToEdit {
                    NavigationView {
                        EditRecipeView(recipe: recipe)
                            .environmentObject(recipeStore)
                    }
                } else {
                    Text("Error: No recipe to edit")
                        .foregroundColor(.red)
                }
            }
            .autoRefresh {
                await recipeStore.refreshRecipes()
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
    let onEditRecipe: ((Recipe) -> Void)?
    let onDeleteRecipe: ((Recipe) -> Void)?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewMode == .list {
                    ForEach(recipes) { recipe in
                        RecipeCard(
                            recipe: recipe,
                            style: .standard,
                            onEdit: onEditRecipe,
                            onDelete: onDeleteRecipe
                        )
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
                            RecipeCard(
                                recipe: recipe,
                                style: .compact,
                                onEdit: onEditRecipe,
                                onDelete: onDeleteRecipe
                            )
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
    let onEdit: ((Recipe) -> Void)?
    let onDelete: ((Recipe) -> Void)?
    
    @EnvironmentObject var favoritesStore: FavoritesStore
    @EnvironmentObject var authStore: AuthStore
    @State private var isFavorite = false
    @State private var isHovered = false
    @State private var showingDeleteAlert = false
    @State private var showingActionMenu = false
    @State private var isPressed = false
    
    enum RecipeCardStyle {
        case standard, compact, featured
    }
    
    private var isOwnRecipe: Bool {
        authStore.currentUser?.id == recipe.createdByUserId
    }
    
    var body: some View {
        // Enhanced Recipe Card with custom Magic UI styling but without conflicting tap gestures
        ZStack {
            // Background with gradient and shadow
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(.systemBackground), Color(.systemBackground).opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.primaryGreen.opacity(0.1))
                        .blur(radius: isHovered ? 20 : 0)
                )
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: isHovered ? 15 : 8,
                    x: 0,
                    y: isHovered ? 8 : 4
                )
            
            // Border gradient
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: isHovered ? 
                            [Color.primaryGreen.opacity(0.3), Color.blue.opacity(0.3)] : 
                            [Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isHovered ? 2 : 0
                )
            
            VStack(alignment: .leading, spacing: 12) {
                // Recipe Image with enhanced styling
                ZStack {
                    AsyncImage(url: URL(string: recipe.imageUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        DefaultRecipeImageView(width: .infinity, height: imageHeight)
                    }
                    .frame(maxWidth: .infinity, maxHeight: imageHeight)
                    .clipped()
                    .cornerRadius(12)
                    
                    // Gradient overlay for better text readability
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .cornerRadius(12)
                    
                    // Action Buttons (Favorite + Edit menu for own recipes, Favorite only for others)
                    VStack {
                        HStack {
                            Spacer()
                            
                            // Favorite Button - always show for all recipes
                            Button(action: {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                    isPressed = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                        isPressed = false
                                    }
                                }
                                toggleFavorite()
                            }) {
                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundColor(isFavorite ? .red : .white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                                    )
                                    .scaleEffect(isPressed ? 0.9 : 1.0)
                                    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
                            }
                            .zIndex(1000) // Ensure button is on top layer
                            
                            // Edit menu - only show for own recipes
                            if isOwnRecipe {
                                Button {
                                    showingActionMenu = true
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .frame(width: 32, height: 32)
                                        .background(
                                            Circle()
                                                .fill(Color.black.opacity(0.6))
                                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                                        )
                                }
                                .scaleEffect(isPressed ? 0.9 : 1.0)
                                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                        isPressed = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                            isPressed = false
                                        }
                                    }
                                    showingActionMenu = true
                                }
                                .zIndex(1000) // Ensure button is on top layer
                            }
                        }
                        .padding(.trailing, 12)
                        .padding(.top, 12)
                        
                        Spacer()
                    }
                }
                
                // Recipe Info with enhanced styling
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.name)
                        .font(style == .compact ? .headline : .title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if style != .compact {
                        Text(recipe.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Enhanced Stats row
                    HStack(spacing: 16) {
                        StatItem(
                            icon: "clock",
                            value: "\(recipe.totalTime)m",
                            color: .blue
                        )
                        
                        if style != .compact {
                            StatItem(
                                icon: "star.fill",
                                value: String(format: "%.1f", recipe.avgRating),
                                color: .yellow
                            )
                        }
                        
                        Spacer()
                    }
                    
                    // Enhanced Tags
                    if !recipe.tags.isEmpty && style != .compact {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(recipe.tags.prefix(3), id: \.self) { tag in
                                    TagChip(tag: tag)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                }
            }
            .padding(16)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isHovered = true
                }
                .onEnded { _ in
                    isHovered = false
                }
        )
        .task {
            await checkFavoriteStatus()
        }
        .confirmationDialog("Recipe Options", isPresented: $showingActionMenu, titleVisibility: .visible) {
            Button("Edit Recipe") {
                onEdit?(recipe)
            }
            
            Button("Delete Recipe", role: .destructive) {
                showingDeleteAlert = true
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose an action for \"\(recipe.name)\"")
        }
        .alert("Delete Recipe", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete?(recipe)
            }
        } message: {
            Text("Are you sure you want to delete \"\(recipe.name)\"? This action cannot be undone.")
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