//
//  MealSelectionBottomSheet.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/22/25.
//

import SwiftUI

struct MealSelectionBottomSheet: View {
    let dayOfWeek: Int
    let mealType: MealType
    let date: Date
    
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @EnvironmentObject var recipeStore: RecipeStore
    @EnvironmentObject var favoritesStore: FavoritesStore
    
    @State private var selectedTab: MealSelectionTab = .search
    @State private var searchText = ""
    // Removed unused state variables
    @State private var customMealName = ""
    @State private var customCalories = ""
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Sheet Header
                sheetHeader
                
                // Tab Selection
                tabSelector
                
                // Content based on selected tab
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarHidden(true)
            .onAppear {
                loadInitialData()
            }
        }
        // Removed serving adjustment sheet as it's no longer needed
    }
}

// MARK: - Header and Navigation

extension MealSelectionBottomSheet {
    private var sheetHeader: some View {
        VStack(spacing: 8) {
            // Drag Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 6)
                .padding(.top, 8)
            
            // Title Section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add \(mealType.rawValue.capitalized)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(dayString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }
    
    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Tab Selection

extension MealSelectionBottomSheet {
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(MealSelectionTab.allCases, id: \.self) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGray6))
        .padding(.vertical, 8)
    }
    
    private func tabButton(for tab: MealSelectionTab) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 6) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                
                Text(tab.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
            }
            .frame(width: 80, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .scaleEffect(selectedTab == tab ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
        }
    }
}

// MARK: - Tab Content

extension MealSelectionBottomSheet {
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .search:
            RecipeSearchTab()
        case .recent:
            RecentMealsTab()
        case .favorites:
            FavoritesTab()
        case .aiRecommended:
            AIRecommendedTab()
        case .custom:
            CustomMealTab()
        }
    }
}

// MARK: - Recipe Search Tab

extension MealSelectionBottomSheet {
    private func RecipeSearchTab() -> some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search recipes...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                        recipeStore.searchQuery = ""
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            Divider()
            
            // Recipe List
            if recipeStore.isLoading && recipeStore.recipes.isEmpty {
                LoadingView(message: "Searching recipes...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if recipeStore.recipes.isEmpty {
                EmptySearchView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(recipeStore.recipes) { recipe in
                            RecipeSelectionCard(recipe: recipe) {
                                selectRecipe(recipe)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .onAppear {
            if recipeStore.recipes.isEmpty {
                Task {
                    await recipeStore.loadRecipes()
                }
            }
        }
    }
    
    private func EmptySearchView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("Search for recipes")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("Type in the search box above to find delicious recipes")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Recent Meals Tab

extension MealSelectionBottomSheet {
    private func RecentMealsTab() -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(mealPlanStore.recentMeals.prefix(10), id: \.id) { recipe in
                    RecipeSelectionCard(recipe: recipe, isRecent: true) {
                        selectRecipe(recipe)
                    }
                }
                
                if mealPlanStore.recentMeals.isEmpty {
                    EmptyRecentView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 50)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    private func EmptyRecentView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Recent Meals")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("Your recently used meals will appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Favorites Tab

extension MealSelectionBottomSheet {
    private func FavoritesTab() -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(favoritesStore.favorites.compactMap { $0.recipe }, id: \.id) { recipe in
                    RecipeSelectionCard(recipe: recipe, isFavorite: true) {
                        selectRecipe(recipe)
                    }
                }
                
                if favoritesStore.favorites.isEmpty {
                    EmptyFavoritesView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 50)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .onAppear {
            Task {
                await favoritesStore.loadFavorites()
            }
        }
    }
    
    private func EmptyFavoritesView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "heart")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Favorite Recipes")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("Your favorite recipes will appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - AI Recommended Tab

extension MealSelectionBottomSheet {
    private func AIRecommendedTab() -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(mealPlanStore.aiRecommendedRecipes, id: \.id) { recipe in
                    RecipeSelectionCard(recipe: recipe, isAIRecommended: true) {
                        selectRecipe(recipe)
                    }
                }
                
                if mealPlanStore.aiRecommendedRecipes.isEmpty {
                    EmptyAIRecommendationsView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 50)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .onAppear {
            loadAIRecommendations()
        }
    }
    
    private func EmptyAIRecommendationsView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("Generating Recommendations")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("AI is finding the perfect meals for you based on your preferences")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Custom Meal Tab

extension MealSelectionBottomSheet {
    private func CustomMealTab() -> some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Create Custom Meal")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meal Name")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        TextField("Enter meal name...", text: $customMealName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estimated Calories")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        TextField("Enter calories...", text: $customCalories)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                    }
                    
                    Button(action: addCustomMeal) {
                        Text("Add Custom Meal")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(
                                LinearGradient(
                                    colors: [.accentColor, .accentColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .disabled(customMealName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }
}

// MARK: - Supporting Views

struct RecipeSelectionCard: View {
    let recipe: Recipe
    let isRecent: Bool
    let isFavorite: Bool
    let isAIRecommended: Bool
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    init(recipe: Recipe, isRecent: Bool = false, isFavorite: Bool = false, isAIRecommended: Bool = false, onTap: @escaping () -> Void) {
        self.recipe = recipe
        self.isRecent = isRecent
        self.isFavorite = isFavorite
        self.isAIRecommended = isAIRecommended
        self.onTap = onTap
    }
    
    var body: some View {
        MagicCard {
            HStack(spacing: 12) {
                // Recipe Image
                AsyncImage(url: URL(string: recipe.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        )
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Recipe Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(recipe.name)
                            .font(.headline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        if isRecent {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        } else if isFavorite {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        } else if isAIRecommended {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.purple)
                                .font(.caption)
                        }
                    }
                    
                    Text(recipe.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        Label("\(recipe.totalTime)m", systemImage: "clock")
                        
                        Label(recipe.difficulty.rawValue.capitalized, systemImage: "chart.bar")
                        
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Add Button
                Button(action: onTap) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .scaleEffect(isHovered ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
                }
            }
            .padding(12)
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
}

// MARK: - Supporting Types and Functions

enum MealSelectionTab: CaseIterable {
    case search
    case recent
    case favorites
    case aiRecommended
    case custom
    
    var title: String {
        switch self {
        case .search: return "Search"
        case .recent: return "Recent"
        case .favorites: return "Favorites"
        case .aiRecommended: return "AI Picks"
        case .custom: return "Custom"
        }
    }
    
    var iconName: String {
        switch self {
        case .search: return "magnifyingglass"
        case .recent: return "clock"
        case .favorites: return "heart"
        case .aiRecommended: return "brain.head.profile"
        case .custom: return "plus.square"
        }
    }
}

// MARK: - Actions

extension MealSelectionBottomSheet {
    private func loadInitialData() {
        Task {
            await recipeStore.loadRecipes()
            await favoritesStore.loadFavorites()
        }
    }
    
    private func performSearch() {
        recipeStore.searchQuery = searchText
        Task {
            await recipeStore.searchRecipes()
        }
    }
    
    private func selectRecipe(_ recipe: Recipe) {
        // Add directly with default serving size (no serving adjustment needed)
        addMealToWeek(with: recipe)
    }
    
    private func addMealToWeek(with recipe: Recipe) {
        Task {
            await mealPlanStore.addMealToWeek(
                recipe: recipe,
                dayOfWeek: dayOfWeek,
                mealType: mealType,
                servingSize: 1.0 // Default serving size
            )
            
            // Add to recent meals
            await mealPlanStore.addToRecentMeals(recipe)
            
            // No need to reload from backend - addMealToWeek already updates the local data
            print("✅ Recipe \(recipe.name) added successfully to \(mealType.rawValue)")
            
            // Dismiss the sheet
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func addCustomMeal() {
        guard !customMealName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let calories = Double(customCalories) ?? 0
        
        Task {
            await mealPlanStore.addCustomMealToWeek(
                name: customMealName.trimmingCharacters(in: .whitespaces),
                calories: calories,
                dayOfWeek: dayOfWeek,
                mealType: mealType
            )
            
            dismiss()
        }
    }
    
    private func loadAIRecommendations() {
        Task {
            await mealPlanStore.loadAIRecommendations(for: mealType)
        }
    }
}

// MARK: - Preview

#Preview {
    MealSelectionBottomSheet(
        dayOfWeek: 0,
        mealType: .breakfast,
        date: Date()
    )
    .environmentObject(MealPlanStore())
    .environmentObject(RecipeStore())
    .environmentObject(FavoritesStore())
}