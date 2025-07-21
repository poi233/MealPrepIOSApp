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
                    .foregroundColor(favoritesStore.hasFilters ? .accentColor : .primary)
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
                        Image(systemName: "arrow.up.arrow.down")
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
                FavoriteDetailView(favorite: favorite)
                    .environmentObject(favoritesStore)
            }
            .task {
                if favoritesStore.favorites.isEmpty {
                    await favoritesStore.loadFavorites()
                }
            }
            .alert("Error", isPresented: .constant(favoritesStore.errorMessage != nil)) {
                Button("OK") {
                    favoritesStore.clearError()
                }
            } message: {
                Text(favoritesStore.errorMessage ?? "")
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
    
    enum FavoriteCardStyle {
        case standard, compact
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Recipe Image
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
            .frame(height: imageHeight)
            .clipped()
            .cornerRadius(8)
            .overlay(
                // Favorite Actions
                VStack {
                    HStack {
                        Spacer()
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
                            Image(systemName: "ellipsis.circle.fill")
                                .foregroundColor(.white)
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
                Text(favorite.recipe.name)
                    .font(style == .compact ? .subheadline : .headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                if style != .compact {
                    Text(favorite.recipe.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Personal Rating
                if let rating = favorite.personalRating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundColor(star <= rating ? .yellow : .gray)
                                .font(.caption)
                        }
                        
                        Text("My Rating")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                }
                
                // Personal Notes
                if let notes = favorite.personalNotes, !notes.isEmpty, style != .compact {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                        .lineLimit(2)
                        .padding(.top, 2)
                }
                
                // Recipe Stats
                HStack(spacing: 12) {
                    Label("\(favorite.recipe.totalTime) min", systemImage: "clock")
                    
                    if style != .compact {
                        Label("\(favorite.recipe.avgRating, specifier: "%.1f")", systemImage: "star.fill")
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    Text("Added \(favorite.addedAt, style: .date)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showingEditView) {
            EditFavoriteView(favorite: favorite)
                .environmentObject(favoritesStore)
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