//
//  FavoritesView.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/20/25.
//

import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var favoritesStore: FavoritesStore
    @State private var showingFilters = false
    @State private var selectedFavorite: Favorite?
    @State private var viewMode: FavoriteViewMode = .list
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                VStack(spacing: 12) {
                    SearchBar(text: $favoritesStore.searchQuery)
                    
                    // Quick Filter Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(
                                title: "5 Stars",
                                isSelected: favoritesStore.selectedRating == 5,
                                action: {
                                    Task {
                                        if favoritesStore.selectedRating == 5 {
                                            favoritesStore.selectedRating = nil
                                            await favoritesStore.applyFilters()
                                        } else {
                                            await favoritesStore.getFavoritesByRating(5)
                                        }
                                    }
                                }
                            )
                            
                            FilterChip(
                                title: "4+ Stars",
                                isSelected: favoritesStore.filters.personalRatingMin == 4,
                                action: {
                                    Task {
                                        if favoritesStore.filters.personalRatingMin == 4 {
                                            await favoritesStore.clearFilters()
                                        } else {
                                            await favoritesStore.getHighlyRatedFavorites()
                                        }
                                    }
                                }
                            )
                            
                            FilterChip(
                                title: "Recent",
                                isSelected: favoritesStore.sortOrder == .addedAtDesc,
                                action: {
                                    Task {
                                        if favoritesStore.sortOrder == .addedAtDesc {
                                            favoritesStore.sortOrder = .recipeNameAsc
                                            await favoritesStore.applyFilters()
                                        } else {
                                            await favoritesStore.getRecentFavorites()
                                        }
                                    }
                                }
                            )
                            
                            // Cuisine filters
                            ForEach(["Italian", "Asian", "Mexican", "American"], id: \.self) { cuisine in
                                FilterChip(
                                    title: cuisine,
                                    isSelected: favoritesStore.selectedCuisine == cuisine,
                                    action: {
                                        Task {
                                            if favoritesStore.selectedCuisine == cuisine {
                                                favoritesStore.selectedCuisine = nil
                                                await favoritesStore.applyFilters()
                                            } else {
                                                await favoritesStore.getFavoritesByCuisine(cuisine)
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
                    Text(favoritesStore.statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // View Mode Toggle
                    Picker("View Mode", selection: $viewMode) {
                        Image(systemName: "list.bullet").tag(FavoriteViewMode.list)
                        Image(systemName: "square.grid.2x2").tag(FavoriteViewMode.grid)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 100)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Content
                if favoritesStore.isLoading && favoritesStore.favorites.isEmpty {
                    LoadingView(message: "Loading favorites...")
                } else if favoritesStore.isEmpty {
                    EmptyFavoritesView()
                } else {
                    FavoriteListView(
                        favorites: favoritesStore.favorites,
                        viewMode: viewMode,
                        isLoadingMore: favoritesStore.isLoadingMore,
                        hasMorePages: favoritesStore.hasMorePages,
                        onFavoriteTap: { favorite in
                            selectedFavorite = favorite
                        },
                        onLoadMore: {
                            Task {
                                await favoritesStore.loadMoreFavorites()
                            }
                        }
                    )
                }
            }
            .navigationTitle("Favorites")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Filters") {
                        showingFilters = true
                    }
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(favoritesStore.hasFilters ? .accentColor : .primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(favoritesStore.hasFilters ? Color.accentColor.opacity(0.1) : Color.clear)
                    )
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Sort by Name") {
                            Task {
                                favoritesStore.sortOrder = .recipeNameAsc
                                await favoritesStore.applyFilters()
                            }
                        }
                        
                        Button("Sort by Rating") {
                            Task {
                                favoritesStore.sortOrder = .personalRatingDesc
                                await favoritesStore.applyFilters()
                            }
                        }
                        
                        Button("Sort by Date Added") {
                            Task {
                                favoritesStore.sortOrder = .addedAtDesc
                                await favoritesStore.applyFilters()
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.accentColor, .accentColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            .refreshable {
                Task {
                    await favoritesStore.refreshFavorites()
                }
            }
            .sheet(isPresented: $showingFilters) {
                FavoriteFiltersView()
                    .environmentObject(favoritesStore)
            }
            .sheet(item: $selectedFavorite) { favorite in
                NavigationView {
                    FavoriteDetailView(favorite: favorite)
                        .environmentObject(favoritesStore)
                }
            }
            .autoRefresh {
                await favoritesStore.refreshFavorites()
            }
        }
    }
}

// MARK: - Supporting Views

enum FavoriteViewMode {
    case list, grid
}

struct FavoriteListView: View {
    let favorites: [Favorite]
    let viewMode: FavoriteViewMode
    let isLoadingMore: Bool
    let hasMorePages: Bool
    let onFavoriteTap: (Favorite) -> Void
    let onLoadMore: () -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewMode == .list {
                    ForEach(favorites) { favorite in
                        FavoriteCard(favorite: favorite, style: .standard)
                            .onTapGesture {
                                onFavoriteTap(favorite)
                            }
                    }
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(favorites) { favorite in
                            FavoriteCard(favorite: favorite, style: .compact)
                                .onTapGesture {
                                    onFavoriteTap(favorite)
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

struct FavoriteCard: View {
    let favorite: Favorite
    let style: FavoriteCardStyle
    @EnvironmentObject var favoritesStore: FavoritesStore
    @State private var showingEditView = false
    @State private var isHovered = false
    
    enum FavoriteCardStyle {
        case standard, compact
    }
    
    var body: some View {
        // Enhanced Favorite Card with custom Magic UI styling but without conflicting tap gestures
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
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )
            
            VStack(alignment: .leading, spacing: 12) {
                // Recipe Image with enhanced styling - matching RecipeCard
                ZStack {
                    AsyncImage(url: URL(string: favorite.recipe.imageUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        DefaultRecipeImageView_Elegant(width: 200, height: 150)
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
                    
                    // Action Buttons - positioned at top like RecipeCard
                    VStack {
                        HStack {
                            Spacer()
                            
                            // Menu Button
                            Menu {
                                Button("Edit Rating & Notes") {
                                    showingEditView = true
                                }
                                
                                Button("Remove from Favorites", role: .destructive) {
                                    Task {
                                        await favoritesStore.removeFromFavorites(recipeId: favorite.recipe.id)
                                    }
                                }
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
                                    .scaleEffect(isHovered ? 1.1 : 1.0)
                            }
                        }
                        .padding(.trailing, 12)
                        .padding(.top, 12)
                        
                        Spacer()
                    }
                }
            
                // Enhanced Recipe Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(favorite.recipe.name)
                        .font(style == .compact ? .headline : .title3)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineLimit(2)
                    
                    if style != .compact {
                        Text(favorite.recipe.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Enhanced Personal Rating
                    if let rating = favorite.personalRating {
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundColor(star <= rating ? .yellow : .gray.opacity(0.3))
                                    .font(.system(size: 14, weight: .medium))
                            }
                            
                            Text("My Rating")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.leading, 6)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            Capsule()
                                .fill(Color.yellow.opacity(0.1))
                        )
                    }
                    
                    // Enhanced Personal Notes
                    if let notes = favorite.personalNotes, !notes.isEmpty, style != .compact {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .lineLimit(2)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.05))
                            )
                    }
                    
                    // Enhanced Recipe Stats
                    HStack(spacing: 16) {
                        StatItem(
                            icon: "clock",
                            value: "\(favorite.recipe.totalTime)m",
                            color: .blue
                        )
                        
                        if style != .compact {
                            StatItem(
                                icon: "star.fill",
                                value: String(format: "%.1f", favorite.recipe.avgRating),
                                color: .orange
                            )
                        }
                        
                        Spacer()
                        
                        Text("Added \(favorite.addedAt, style: .date)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.1))
                            )
                    }
                }
            }
            .padding()
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
        .sheet(isPresented: $showingEditView) {
            NavigationView {
                EditFavoriteView(favorite: favorite)
                    .environmentObject(favoritesStore)
            }
        }
    }
    
    private var imageHeight: CGFloat {
        switch style {
        case .standard: return 150
        case .compact: return 120
        }
    }
}

struct EmptyFavoritesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Favorites Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start exploring recipes and tap the heart icon to save your favorites!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Browse Recipes") {
                // TODO: Navigate to recipes tab
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// Shared components are now in SharedComponents.swift

#Preview {
    FavoritesView()
        .environmentObject(FavoritesStore())
}