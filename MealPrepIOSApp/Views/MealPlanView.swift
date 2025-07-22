//
//  MealPlanView.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/20/25.
//

import SwiftUI

struct MealPlanView: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @State private var showingGenerationView = false
    @State private var showingMealPlanList = false
    @State private var showingAnalysisView = false
    @State private var showingShoppingList = false
    @State private var showingBatchOperations = false
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
                        showingGenerationView = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
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
            .sheet(isPresented: $showingGenerationView) {
                MealPlanGenerationView()
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
            
            if mealPlanStore.activeMealPlan != nil {
                // Weekly Grid
                WeeklyMealGridView()
            } else if mealPlanStore.isLoading {
                LoadingView(message: "Loading meal plan...")
            } else {
                EmptyWeekView()
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
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(mealPlanStore.weeklyGrid.dailyMeals.enumerated()), id: \.element.id) { index, dailyMeal in
                DailyMealCard(dailyMeal: dailyMeal, dayOfWeek: index)
                }
            }
            .padding()
        }
    }
}

struct DailyMealCard: View {
    let dailyMeal: DailyMealSlots
    let dayOfWeek: Int
    @State private var isHovered = false
    
    var body: some View {
        BlurFade(delay: 0.1) {
            MagicCard {
                VStack(alignment: .leading, spacing: 16) {
                    // Enhanced Day Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dailyMeal.day)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.primary, .accentColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text(dailyMeal.date, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Day status indicator
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 12, height: 12)
                            .scaleEffect(isHovered ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
                    }
                    
                    // Enhanced Meal Slots
                    VStack(spacing: 12) {
                        MealSlotView(title: "Breakfast", recipes: dailyMeal.breakfast, mealType: .breakfast, dayOfWeek: dayOfWeek, date: dailyMeal.date)
                        MealSlotView(title: "Lunch", recipes: dailyMeal.lunch, mealType: .lunch, dayOfWeek: dayOfWeek, date: dailyMeal.date)
                        MealSlotView(title: "Dinner", recipes: dailyMeal.dinner, mealType: .dinner, dayOfWeek: dayOfWeek, date: dailyMeal.date)
                        MealSlotView(title: "Snack", recipes: dailyMeal.snack, mealType: .snack, dayOfWeek: dayOfWeek, date: dailyMeal.date)
                    }
                }
            }
            .scaleEffect(isHovered ? 1.01 : 1.0)
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
}

struct MealSlotView: View {
    let title: String
    let recipes: [Recipe]
    let mealType: MealType
    let dayOfWeek: Int
    let date: Date
    
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @State private var isAddHovered = false
    @State private var showingMealSelection = false
    @State private var showingMealActions = false
    @State private var selectedRecipe: Recipe?
    @State private var selectedMealPlanItem: MealPlanItem?
    
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
        HStack(spacing: 12) {
            // Enhanced meal type indicator
            VStack(spacing: 4) {
                Image(systemName: mealIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(mealColor)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(mealColor.opacity(0.1))
                    )
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .frame(width: 70)
            
            if recipes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No meal planned")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                    
                    Text("Tap to add a recipe")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                Spacer()
                
                Button(action: {
                    showingMealSelection = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .scaleEffect(isAddHovered ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAddHovered)
                }
                .onHover { hovering in
                    isAddHovered = hovering
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(recipes) { recipe in
                        Button(action: {
                            selectedRecipe = recipe
                            // Find the corresponding meal plan item
                            selectedMealPlanItem = mealPlanStore.findMealPlanItem(
                                recipeId: recipe.id,
                                dayOfWeek: dayOfWeek,
                                mealType: mealType
                            )
                            showingMealActions = true
                        }) {
                            HStack(spacing: 8) {
                                Text(recipe.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                // Recipe time indicator
                                Text("\(recipe.totalTime)m")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.secondary.opacity(0.1))
                                    )
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(mealColor.opacity(0.05))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
        .sheet(isPresented: $showingMealActions) {
            if let recipe = selectedRecipe,
               let mealPlanItem = selectedMealPlanItem {
                MealActionSheet(
                    mealPlanItem: mealPlanItem,
                    recipe: recipe
                )
                .environmentObject(mealPlanStore)
                .environmentObject(RecipeStore())
            }
        }
    }
}

struct EmptyWeekView: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Meal Plan for This Week")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Generate an AI-powered meal plan to get started!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Generate Meal Plan") {
                mealPlanStore.showingGenerationView = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
            
            Text("Create your first AI-powered meal plan to get started!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Generate Meal Plan") {
                mealPlanStore.showingGenerationView = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Supporting Views

// LoadingView is now in SharedComponents.swift

#Preview {
    MealPlanView()
        .environmentObject(MealPlanStore())
}