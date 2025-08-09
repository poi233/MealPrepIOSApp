//
//  MealPlanView.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/20/25.
//

import SwiftUI

struct MealPlanView: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @EnvironmentObject var recipeStore: RecipeStore

    @State private var showingAnalysisView = false
    @State private var showingShoppingList = false
    @State private var showingBatchOperations = false
    @State private var showingTemplateSheet = false
    @State private var showingAIWorkflow = false
    var body: some View {
        NavigationView {
            WeeklyMealPlanView()
            .navigationTitle("Meal Plans")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        if mealPlanStore.currentMealPlan != nil {
                            Button("Analyze Plan") {
                                showingAnalysisView = true
                            }

                            Button("Shopping List") {
                                showingShoppingList = true
                            }

                            Divider()

                            Button("Batch Operations") {
                                showingBatchOperations = true
                            }

                            Divider()

                            Button("AI Generate Week") {
                                showingAIWorkflow = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.secondary, .secondary.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // AI Generation Button
                    Button {
                        showingAIWorkflow = true
                    } label: {
                        Label("AI Generate", systemImage: "brain")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .purple.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    // Template Button
                    Button {
                        showingTemplateSheet = true
                    } label: {
                        Label("Add to Template", systemImage: "folder.badge.plus")
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
            .sheet(isPresented: $showingTemplateSheet) {
                MealPlanTemplateSheet()
                    .environmentObject(mealPlanStore)
            }

            .sheet(isPresented: $showingAnalysisView) {
                MealPlanAnalysisView()
                    .environmentObject(mealPlanStore)
            }
            .sheet(isPresented: $showingShoppingList) {
                ShoppingListView()
                    .environmentObject(mealPlanStore)
            }
            .sheet(isPresented: $showingBatchOperations) {
                BatchOperationsSheet()
                    .environmentObject(mealPlanStore)
            }
            .fullScreenCover(isPresented: $showingAIWorkflow) {
                AIWeeklyWorkflowView()
                    .environmentObject(mealPlanStore)
                    .environmentObject(recipeStore)
            }
            .autoRefresh {
                await mealPlanStore.refreshMealPlans()
            }
        }
    }
}

// MARK: - Weekly Meal Plan View

struct WeeklyMealPlanView: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore

    var body: some View {
        VStack(spacing: 0) {
            // Week Navigation
            WeekNavigationView()

            if mealPlanStore.isLoading {
                LoadingView(message: "Loading meal plan...")
            } else {
                // Always show the weekly grid, even if empty
                WeeklyMealGridView()
            }
        }
    }
}

struct WeekNavigationView: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore

    var body: some View {
        HStack {
            Button(action: {
                Task {
                    await mealPlanStore.navigateToWeek(.previous)
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(mealPlanStore.canNavigateToPreviousWeek ? .primary : .gray)
            }
            .disabled(!mealPlanStore.canNavigateToPreviousWeek)

            Spacer()

            VStack(spacing: 2) {
                Text(weekTitle)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(weekSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                Task {
                    await mealPlanStore.navigateToWeek(.next)
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(mealPlanStore.canNavigateToNextWeek ? .primary : .gray)
            }
            .disabled(!mealPlanStore.canNavigateToNextWeek)
        }
        .padding()
        .background(Color(.systemGray6))
    }

    private var weekTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let startDate = mealPlanStore.selectedWeekStartDate
        let endDate = Calendar.mondayFirst.date(byAdding: .day, value: 6, to: startDate) ?? startDate

        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    private var weekSubtitle: String {
        let calendar = Calendar.mondayFirst
        let now = Date()
        let currentWeekStart = now.startOfWeek()
        let selectedWeekStart = mealPlanStore.selectedWeekStartDate

        if calendar.isDate(selectedWeekStart, equalTo: currentWeekStart, toGranularity: .weekOfYear) {
            return "This Week"
        } else if selectedWeekStart < currentWeekStart {
            return "Past Week"
        } else {
            return "Future Week"
        }
    }
}

struct WeeklyMealGridView: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore

    private var sortedDailyMeals: [(dailyMeal: DailyMealSlots, dayOfWeek: Int)] {
        let calendar = Calendar.mondayFirst
        let today = Date()
        let todayMondayBasedWeekday = today.mondayBasedWeekday() // Monday = 0, Tuesday = 1, etc.

        let dailyMealsWithIndex = Array(mealPlanStore.weeklyGrid.dailyMeals.enumerated())
            .map { (dailyMeal: $0.element, dayOfWeek: $0.offset) }

        // Check if we're viewing the current week
        let currentWeekStart = today.startOfWeek()
        let selectedWeekStart = mealPlanStore.selectedWeekStartDate
        let isCurrentWeek = calendar.isDate(selectedWeekStart, equalTo: currentWeekStart, toGranularity: .weekOfYear)

        if isCurrentWeek {
            // Current week: Today first, then future days, then past days
            let todayMeals = dailyMealsWithIndex.filter { $0.dayOfWeek == todayMondayBasedWeekday }
            let futureMeals = dailyMealsWithIndex.filter { $0.dayOfWeek > todayMondayBasedWeekday }
            let pastMeals = dailyMealsWithIndex.filter { $0.dayOfWeek < todayMondayBasedWeekday }

            return todayMeals + futureMeals + pastMeals
        } else {
            // Past/future week: normal Monday-first order (Monday=0, Tuesday=1, etc.)
            return dailyMealsWithIndex
        }
    }

    private var sortedLightweightMeals: [(lightweightMeal: LightweightDailyMeal, dayOfWeek: Int)] {
        let calendar = Calendar.mondayFirst
        let today = Date()
        let todayMondayBasedWeekday = today.mondayBasedWeekday()

        let lightweightMealsWithIndex = Array(mealPlanStore.lightweightDailyMeals.enumerated())
            .map { (lightweightMeal: $0.element, dayOfWeek: $0.offset) }

        // Check if we're viewing the current week
        let currentWeekStart = today.startOfWeek()
        let selectedWeekStart = mealPlanStore.selectedWeekStartDate
        let isCurrentWeek = calendar.isDate(selectedWeekStart, equalTo: currentWeekStart, toGranularity: .weekOfYear)

        if isCurrentWeek {
            // Current week: Today first, then future days, then past days
            let todayMeals = lightweightMealsWithIndex.filter { $0.dayOfWeek == todayMondayBasedWeekday }
            let futureMeals = lightweightMealsWithIndex.filter { $0.dayOfWeek > todayMondayBasedWeekday }
            let pastMeals = lightweightMealsWithIndex.filter { $0.dayOfWeek < todayMondayBasedWeekday }

            return todayMeals + futureMeals + pastMeals
        } else {
            // Past/future week: normal Monday-first order (Monday=0, Tuesday=1, etc.)
            return lightweightMealsWithIndex
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Show lightweight meal suggestions if available
                if mealPlanStore.hasLightweightMeals {
                    ForEach(sortedLightweightMeals, id: \.lightweightMeal.id) { item in
                        LightweightDailyMealCard(
                            lightweightDailyMeal: item.lightweightMeal,
                            dayOfWeek: item.dayOfWeek,
                            date: Calendar.mondayFirst.date(byAdding: .day, value: item.dayOfWeek, to: mealPlanStore.selectedWeekStartDate) ?? Date()
                        )
                    }
                } else {
                    // Show traditional daily meal cards
                    ForEach(sortedDailyMeals, id: \.dailyMeal.id) { item in
                        DailyMealCard(dailyMeal: item.dailyMeal, dayOfWeek: item.dayOfWeek)
                    }
                }
            }
            .padding()
        }
    }
}

struct DailyMealCard: View {
    let dailyMeal: DailyMealSlots
    let dayOfWeek: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Clean Day Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dailyMeal.day)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(dailyMeal.date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Clean Meal Slots
            VStack(spacing: 16) {
                MealSlotView(title: "Breakfast", recipes: dailyMeal.breakfast, mealType: .breakfast, dayOfWeek: dayOfWeek, date: dailyMeal.date)
                MealSlotView(title: "Lunch", recipes: dailyMeal.lunch, mealType: .lunch, dayOfWeek: dayOfWeek, date: dailyMeal.date)
                MealSlotView(title: "Dinner", recipes: dailyMeal.dinner, mealType: .dinner, dayOfWeek: dayOfWeek, date: dailyMeal.date)

            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }


}

struct MealSlotView: View {
    let title: String
    let recipes: [Recipe]
    let mealType: MealType
    let dayOfWeek: Int
    let date: Date

    @EnvironmentObject var mealPlanStore: MealPlanStore
    @EnvironmentObject var favoritesStore: FavoritesStore
    @State private var showingMealSelection = false
    @State private var showingRecipeDetail = false
    @State private var selectedRecipe: Recipe?

    private var mealIcon: String {
        switch mealType {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon"
        }
    }

    private var mealColor: Color {
        switch mealType {
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .purple
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Meal type header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: mealIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(mealColor)

                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }

                Spacer()

                // Add button - always visible, larger size
                Button(action: {
                    showingMealSelection = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.primaryGreen)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 32, height: 32)
            }

            // Recipe list - support multiple recipes
            if recipes.isEmpty {
                Text("Tap + to add recipes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                VStack(spacing: 6) {
                    ForEach(recipes) { recipe in
                        HStack(spacing: 8) {
                            // Large recipe button (takes most space)
                            Button(action: {
                                print("🔍 Recipe card tapped: \(recipe.name) (ID: \(recipe.id))")

                                // Validate recipe before setting
                                guard !recipe.id.isEmpty && !recipe.name.isEmpty else {
                                    print("⚠️ Invalid recipe data, cannot show details")
                                    return
                                }

                                // Set recipe to trigger sheet - using .sheet(item:) pattern
                                selectedRecipe = recipe
                                print("📱 Sheet triggered for recipe: \(recipe.name)")
                            }) {
                                HStack(spacing: 8) {
                                    // Recipe icon
                                    Circle()
                                        .fill(mealColor.opacity(0.2))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Image(systemName: "fork.knife")
                                                .font(.caption)
                                                .foregroundColor(mealColor)
                                        )

                                    Text(recipe.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                        .foregroundColor(.primary)

                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(mealColor.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Two small action buttons on the right (horizontal layout)
                            HStack(spacing: 4) {
                                // Favorite button
                                Button(action: {
                                    toggleFavorite(recipe)
                                }) {
                                    FavoriteButtonView(recipe: recipe)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(width: 32, height: 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.white)
                                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                                )

                                // Delete button
                                Button(action: {
                                    removeRecipeFromMealPlan(recipe)
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.red)
                                        .frame(width: 16, height: 16)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(width: 32, height: 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.white)
                                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
        .sheet(isPresented: $showingMealSelection) {
            MealSelectionBottomSheet(
                dayOfWeek: dayOfWeek,
                mealType: mealType,
                date: date
            )
            .environmentObject(mealPlanStore)
            // Use existing environment objects instead of creating new instances
            // This prevents duplicate API calls on sheet presentation
        }
        .sheet(item: $selectedRecipe) { recipe in
            NavigationView {
                RecipeDetailView(recipe: recipe, isFromMealPlan: true)
                    .navigationBarTitleDisplayMode(.large)
            }
            // Use existing environment objects instead of creating new instances
            // This prevents duplicate API calls
            .onAppear {
                print("📱 Recipe detail sheet appeared for: \(recipe.name)")
            }
        }
    }

    // MARK: - Helper Methods

    private func toggleFavorite(_ recipe: Recipe) {
        Task {
            do {
                print("🔄 Toggling favorite for recipe: \(recipe.name)")
                // Use the environment object instead of creating a new instance
                let newStatus = try await favoritesStore.toggleFavorite(recipeId: recipe.id, rating: nil, notes: nil)
                print("✅ Toggled favorite for recipe: \(recipe.name), new status: \(newStatus)")

                // Force update the favorite button view by triggering a re-render
                await MainActor.run {
                    // This will cause FavoriteButtonView to refresh
                    NotificationCenter.default.post(
                        name: NSNotification.Name("FavoriteStatusChanged"),
                        object: recipe.id,
                        userInfo: ["newStatus": newStatus]
                    )
                }
            } catch {
                print("❌ Failed to toggle favorite for recipe: \(recipe.name), error: \(error)")
            }
        }
    }

    private func removeRecipeFromMealPlan(_ recipe: Recipe) {
        Task {
            await MainActor.run {
                // Remove recipe from the appropriate meal type
                switch mealType {
                case .breakfast:
                    if let index = mealPlanStore.weeklyGrid.dailyMeals[dayOfWeek].breakfast.firstIndex(where: { $0.id == recipe.id }) {
                        mealPlanStore.weeklyGrid.dailyMeals[dayOfWeek].breakfast.remove(at: index)
                    }
                case .lunch:
                    if let index = mealPlanStore.weeklyGrid.dailyMeals[dayOfWeek].lunch.firstIndex(where: { $0.id == recipe.id }) {
                        mealPlanStore.weeklyGrid.dailyMeals[dayOfWeek].lunch.remove(at: index)
                    }
                case .dinner:
                    if let index = mealPlanStore.weeklyGrid.dailyMeals[dayOfWeek].dinner.firstIndex(where: { $0.id == recipe.id }) {
                        mealPlanStore.weeklyGrid.dailyMeals[dayOfWeek].dinner.remove(at: index)
                    }
                }

                print("✅ Removed \(recipe.name) from \(mealType.rawValue) for day \(dayOfWeek)")
            }

            // Save changes to local storage
            mealPlanStore.saveLocalMealPlan()
        }
    }
}



// MARK: - Supporting Views

// Favorite button component that shows current favorite status
struct FavoriteButtonView: View {
    let recipe: Recipe
    @EnvironmentObject var favoritesStore: FavoritesStore
    @State private var isFavorite = false
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isFavorite ? .red : .gray)
                    .frame(width: 24, height: 24)
            }
        }
        .onAppear {
            loadFavoriteStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FavoriteStatusChanged"))) { notification in
            // Update when favorite status changes for this recipe
            if let recipeId = notification.object as? String, recipeId == recipe.id {
                print("📡 Received favorite status change notification for recipe: \(recipe.name)")
                // Check if we have the new status in userInfo
                if let userInfo = notification.userInfo,
                   let newStatus = userInfo["newStatus"] as? Bool {
                    // Use the provided status immediately
                    DispatchQueue.main.async {
                        isFavorite = newStatus
                        print("❤️ Updated favorite status to: \(newStatus) for recipe: \(recipe.name)")
                    }
                } else {
                    // Fallback to loading from server
                    loadFavoriteStatus()
                }
            }
        }
    }

    private func loadFavoriteStatus() {
        // First try to use cached status to avoid API call
        let cachedStatus = favoritesStore.isFavorite(recipeId: recipe.id)
        isFavorite = cachedStatus
        print("📖 [FavoriteButtonView] Using cached favorite status for recipe \(recipe.id): \(cachedStatus)")

        // Only make API call if cache is potentially stale (not implemented yet)
        // For now, rely on the cached status to reduce API calls
        isLoading = false
    }
}

// LoadingView is now in SharedComponents.swift

#Preview {
    MealPlanView()
        .environmentObject(MealPlanStore())
        .environmentObject(RecipeStore())
}
