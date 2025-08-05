//
//  FavoritesView.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/26/25.
//

import SwiftUI
import Foundation

struct FavoritesView: View {
    @EnvironmentObject var favoritesStore: FavoritesStore
    @EnvironmentObject var recipeStore: RecipeStore
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
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Content
                if favoritesStore.isLoading && favoritesStore.favorites.isEmpty {
                    EnhancedLoadingView(message: "Loading your favorite recipes...")
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
                    .foregroundColor(favoritesStore.hasFilters ? .primaryGreen : .primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(favoritesStore.hasFilters ? Color.primaryGreen.opacity(0.1) : Color.clear)
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
                    await favoritesStore.refreshFavorites()
                }
            }
            .sheet(isPresented: $showingFilters) {
                FavoriteFiltersView()
                    .environmentObject(favoritesStore)
            }
            .sheet(item: $selectedFavorite) { favorite in
                NavigationView {
                    RecipeDetailView(recipe: favorite.recipe, isFromMealPlan: false)
                        .environmentObject(recipeStore)
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
                        LoadMoreIndicator()
                            .padding()
                    } else {
                        Button("Load More") {
                            onLoadMore()
                        }
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryGreen)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.primaryGreen.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.primaryGreen.opacity(0.3), lineWidth: 1)
                                )
                        )
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
                // Recipe Image with enhanced styling and loading animation
                ZStack {
                    RecipeImageView(
                        recipe: favorite.recipe,
                        width: 200,
                        height: imageHeight,
                        cornerRadius: 12,
                        showLoadingAnimation: true
                    )
                    .frame(maxWidth: .infinity, maxHeight: imageHeight)
                    .clipped()
                    
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
                            
                            // Delete Favorite Button
                            Button {
                                Task {
                                    await favoritesStore.removeFromFavorites(recipeId: favorite.recipe.id)
                                }
                            } label: {
                                Image(systemName: "heart.slash.fill")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(0.9))
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
                        .foregroundColor(.primary)
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
                                    .fill(Color.primaryGreen.opacity(0.05))
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
    }
    
    private var imageHeight: CGFloat {
        switch style {
        case .standard: return 150
        case .compact: return 120
        }
    }
}

// MARK: - Enhanced Loading View

struct EnhancedLoadingView: View {
    let message: String
    
    @State private var isAnimating = false
    @State private var currentDotIndex = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated heart icon
            ZStack {
                // Background circle with pulse
                Circle()
                    .fill(Color.primaryGreen.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                // Heart icon with beat animation
                Image(systemName: "heart.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primaryGreen, .primaryGreen.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
            
            VStack(spacing: 12) {
                Text(message)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                // Animated loading dots
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.primaryGreen)
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentDotIndex == index ? 1.3 : 1.0)
                            .opacity(currentDotIndex == index ? 1.0 : 0.5)
                            .animation(.easeInOut(duration: 0.3), value: currentDotIndex)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isAnimating = true
            startDotAnimation()
        }
        .onDisappear {
            isAnimating = false
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startDotAnimation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation {
                currentDotIndex = (currentDotIndex + 1) % 3
            }
        }
    }
}

// MARK: - Enhanced Empty Favorites View

struct EmptyFavoritesView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Animated illustration
            ZStack {
                // Background circles
                Circle()
                    .fill(Color.primaryGreen.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Circle()
                    .fill(Color.primaryGreen.opacity(0.05))
                    .frame(width: 160, height: 160)
                    .scaleEffect(isAnimating ? 0.9 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 2.5)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                // Heart icon
                Image(systemName: "heart")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.secondary, .secondary.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.8)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
            
            VStack(spacing: 16) {
                Text("No Favorites Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Start exploring recipes and tap the heart icon to save your favorites!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(2)
                
                // Tips
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.circle.fill")
                            .foregroundColor(.primaryGreen)
                        Text("Tap the heart icon on any recipe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "star.circle.fill")
                            .foregroundColor(.yellow)
                        Text("Rate and add personal notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .foregroundColor(.blue)
                        Text("Search and filter your collection")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            
            // Action button
            Button {
                // TODO: Navigate to recipes tab
                // This could be implemented with a TabView selection binding
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("Browse Recipes")
                }
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.primaryGreen, .primaryGreen.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(25)
                .shadow(
                    color: .primaryGreen.opacity(0.3),
                    radius: 8,
                    x: 0,
                    y: 4
                )
            }
            .scaleEffect(isAnimating ? 1.02 : 1.0)
            .animation(
                Animation.easeInOut(duration: 2.2)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

// MARK: - Load More Indicator

struct LoadMoreIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Animated loading dots
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.primaryGreen)
                        .frame(width: 6, height: 6)
                        .scaleEffect(isAnimating ? 1.0 : 0.5)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
            
            Text("Loading more favorites...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

// Shared components are now in SharedComponents.swift

#Preview {
    FavoritesView()
        .environmentObject(FavoritesStore())
}