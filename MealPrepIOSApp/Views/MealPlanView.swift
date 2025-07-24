//
//  MealPlanView.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/20/25.
//

import SwiftUI

struct MealPlanView: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @State private var showingMealPlanList = false
    @State private var showingAnalysisView = false
    @State private var showingShoppingList = false
    @State private var showingBatchOperations = false
    @State private var showingTemplateSheet = false
    @State private var selectedViewMode: MealPlanViewMode = .weekly
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // View Mode Selector
                Picker("View Mode", selection: $selectedViewMode) {
                    Text("Weekly").tag(MealPlanViewMode.weekly)
                    Text("List").tag(MealPlanViewMode.list)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content based on view mode
                if selectedViewMode == .weekly {
                    WeeklyMealPlanView()
                } else {
                    MealPlanListView()
                }
            }
            .navigationTitle("Meal Plans")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("All Meal Plans") {
                            showingMealPlanList = true
                        }
                        
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingTemplateSheet = true
                    } label: {
                        Label("Add to Template", systemImage: "folder.badge.plus")
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
            .sheet(isPresented: $showingTemplateSheet) {
                MealPlanTemplateSheet()
                    .environmentObject(mealPlanStore)
            }
            .sheet(isPresented: $showingMealPlanList) {
                MealPlanListSheet()
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
            .autoRefresh {
                await mealPlanStore.refreshMealPlans()
            }
        }
    }
}

// MARK: - View Mode Enum

enum MealPlanViewMode {
    case weekly, list
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
            }
            
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
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var weekTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startDate = mealPlanStore.selectedWeekStartDate
        let endDate = Calendar.current.date(byAdding: .day, value: 6, to: startDate) ?? startDate
        
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    private var weekSubtitle: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDate(mealPlanStore.selectedWeekStartDate, equalTo: now, toGranularity: .weekOfYear) {
            return "This Week"
        } else if mealPlanStore.selectedWeekStartDate < now {
            return "Past Week"
        } else {
            return "Future Week"
        }
    }
}

struct WeeklyMealGridView: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore
    
    private var sortedDailyMeals: [(dailyMeal: DailyMealSlots, dayOfWeek: Int)] {
        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today) - 1 // Sunday = 0
        
        let dailyMealsWithIndex = Array(mealPlanStore.weeklyGrid.dailyMeals.enumerated())
            .map { (dailyMeal: $0.element, dayOfWeek: $0.offset) }
        
        // Check if we're viewing the current week
        let weekStart = mealPlanStore.selectedWeekStartDate
        let isCurrentWeek = calendar.isDate(weekStart, equalTo: today, toGranularity: .weekOfYear)
        
        if isCurrentWeek {
            // Current week: Today first, then future days, then past days
            let todayMeals = dailyMealsWithIndex.filter { $0.dayOfWeek == currentWeekday }
            let futureMeals = dailyMealsWithIndex.filter { $0.dayOfWeek > currentWeekday }
            let pastMeals = dailyMealsWithIndex.filter { $0.dayOfWeek < currentWeekday }
            
            return todayMeals + futureMeals + pastMeals
        } else {
            // Past/future week: normal order
            return dailyMealsWithIndex
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(sortedDailyMeals, id: \.dailyMeal.id) { item in
                    DailyMealCard(dailyMeal: item.dailyMeal, dayOfWeek: item.dayOfWeek)
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
                
                // Simple status indicator
                if hasMeals {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                }
            }
            
            // Clean Meal Slots
            VStack(spacing: 16) {
                MealSlotView(title: "Breakfast", recipes: dailyMeal.breakfast, mealType: .breakfast, dayOfWeek: dayOfWeek, date: dailyMeal.date)
                MealSlotView(title: "Lunch", recipes: dailyMeal.lunch, mealType: .lunch, dayOfWeek: dayOfWeek, date: dailyMeal.date)
                MealSlotView(title: "Dinner", recipes: dailyMeal.dinner, mealType: .dinner, dayOfWeek: dayOfWeek, date: dailyMeal.date)
                MealSlotView(title: "Snack", recipes: dailyMeal.snack, mealType: .snack, dayOfWeek: dayOfWeek, date: dailyMeal.date)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private var hasMeals: Bool {
        !dailyMeal.breakfast.isEmpty || 
        !dailyMeal.lunch.isEmpty || 
        !dailyMeal.dinner.isEmpty || 
        !dailyMeal.snack.isEmpty
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
        case .snack: return "leaf"
        }
    }
    
    private var mealColor: Color {
        switch mealType {
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .purple
        case .snack: return .green
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
                        .foregroundColor(.accentColor)
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
                        ZStack {
                            // Full-area clickable background
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(mealColor.opacity(0.2), lineWidth: 1)
                                )
                                .onTapGesture {
                                    print("🔍 Recipe card tapped: \(recipe.name) (ID: \(recipe.id))")
                                    
                                    // Validate recipe before setting
                                    guard !recipe.id.isEmpty && !recipe.name.isEmpty else {
                                        print("⚠️ Invalid recipe data, cannot show details")
                                        return
                                    }
                                    
                                    // Set recipe to trigger sheet - using .sheet(item:) pattern
                                    selectedRecipe = recipe
                                    print("📱 Sheet triggered for recipe: \(recipe.name)")
                                }
                            
                            // Recipe content
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
                            .allowsHitTesting(false) // Allow tap to pass through to background
                            
                            // Top overlay action buttons - highest z-index
                            HStack {
                                Spacer()
                                
                                HStack(spacing: 6) {
                                    // Favorite button - shows current state
                                    Button(action: {
                                        toggleFavorite(recipe)
                                    }) {
                                        FavoriteButtonView(recipe: recipe)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(.white)
                                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                                    )
                                    .zIndex(10) // Ensure it's on top
                                    
                                    // Delete button
                                    Button(action: {
                                        removeRecipeFromMealPlan(recipe)
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.red)
                                            .frame(width: 24, height: 24)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(.white)
                                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                                    )
                                    .zIndex(10) // Ensure it's on top
                                }
                                .padding(.trailing, 8)
                                .padding(.top, 4)
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
            .environmentObject(RecipeStore())
            .environmentObject(FavoritesStore())
        }
        .sheet(item: $selectedRecipe) { recipe in
            NavigationView {
                RecipeDetailView(recipe: recipe)
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                print("📱 Done button tapped, dismissing sheet")
                                selectedRecipe = nil
                            }
                        }
                    }
            }
            .environmentObject(RecipeStore())
            .environmentObject(FavoritesStore())
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
                case .snack:
                    if let index = mealPlanStore.weeklyGrid.dailyMeals[dayOfWeek].snack.firstIndex(where: { $0.id == recipe.id }) {
                        mealPlanStore.weeklyGrid.dailyMeals[dayOfWeek].snack.remove(at: index)
                    }
                }
                
                print("✅ Removed \(recipe.name) from \(mealType.rawValue) for day \(dayOfWeek)")
            }
            
            // Save changes to local storage
            mealPlanStore.saveLocalMealPlan()
        }
    }
}



// MARK: - Meal Plan List View

struct MealPlanListView: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore
    
    var body: some View {
        if mealPlanStore.isLoading && mealPlanStore.mealPlans.isEmpty {
            LoadingView(message: "Loading meal plans...")
        } else if mealPlanStore.mealPlans.isEmpty && !mealPlanStore.isLoading {
            EmptyMealPlanListView()
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(mealPlanStore.mealPlans) { mealPlan in
                        MealPlanCard(mealPlan: mealPlan)
                            .onTapGesture {
                                mealPlanStore.currentMealPlan = mealPlan
                            }
                    }
                    
                    // Load More
                    if mealPlanStore.hasMorePages {
                        if mealPlanStore.isLoading {
                            ProgressView()
                                .padding()
                        } else {
                            Button("Load More") {
                                Task {
                                    await mealPlanStore.loadMoreMealPlans()
                                }
                            }
                            .padding()
                            .onAppear {
                                Task {
                                    await mealPlanStore.loadMoreMealPlans()
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                Task {
                    await mealPlanStore.refreshMealPlans()
                }
            }
        }
    }
}

struct MealPlanCard: View {
    let mealPlan: MealPlan
    @EnvironmentObject var mealPlanStore: MealPlanStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mealPlan.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let description = mealPlan.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(mealPlan.weekStartDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if mealPlanStore.currentMealPlan?.id == mealPlan.id {
                        Text("Current")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
            }
            
            // Meal Summary
            HStack(spacing: 16) {
                Label("7 days", systemImage: "calendar")
                Label("\(totalMeals) meals", systemImage: "fork.knife")
                
                Spacer()
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var totalMeals: Int {
        return mealPlan.items?.count ?? 0
    }
}

struct EmptyMealPlanListView: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Meal Plans Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start planning your meals by adding recipes to the weekly view.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
        isLoading = true
        Task {
            do {
                let status = try await favoritesStore.checkFavoriteStatus(recipeId: recipe.id)
                await MainActor.run {
                    isFavorite = status.isFavorite
                    isLoading = false
                    print("🔄 Loaded favorite status: \(status.isFavorite) for recipe: \(recipe.name)")
                }
            } catch {
                // Handle error silently, default to not favorite
                await MainActor.run {
                    isFavorite = false
                    isLoading = false
                    print("⚠️ Failed to load favorite status for recipe: \(recipe.name), error: \(error)")
                }
            }
        }
    }
}

// LoadingView is now in SharedComponents.swift

#Preview {
    MealPlanView()
        .environmentObject(MealPlanStore())
}