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
                        
                        if mealPlanStore.hasCurrentMealPlan {
                            Button("Analyze Plan") {
                                showingAnalysisView = true
                            }
                            
                            Button("Shopping List") {
                                showingShoppingList = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingGenerationView = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
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
            .task {
                if mealPlanStore.mealPlans.isEmpty {
                    await mealPlanStore.loadMealPlans()
                }
            }
            .alert("Error", isPresented: .constant(mealPlanStore.errorMessage != nil)) {
                Button("OK") {
                    mealPlanStore.clearError()
                }
            } message: {
                Text(mealPlanStore.errorMessage ?? "")
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
                ForEach(mealPlanStore.weeklyGrid.dailyMeals) { dailyMeal in
                    DailyMealCard(dailyMeal: dailyMeal)
                }
            }
            .padding()
        }
    }
}

struct DailyMealCard: View {
    let dailyMeal: DailyMealSlots
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day Header
            HStack {
                Text(dailyMeal.day)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(dailyMeal.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Meal Slots
            VStack(spacing: 8) {
                MealSlotView(title: "Breakfast", recipes: dailyMeal.breakfast, mealType: .breakfast)
                MealSlotView(title: "Lunch", recipes: dailyMeal.lunch, mealType: .lunch)
                MealSlotView(title: "Dinner", recipes: dailyMeal.dinner, mealType: .dinner)
                MealSlotView(title: "Snack", recipes: dailyMeal.snack, mealType: .snack)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct MealSlotView: View {
    let title: String
    let recipes: [Recipe]
    let mealType: MealType
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            if recipes.isEmpty {
                Text("No meal planned")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                
                Spacer()
                
                Button("Add") {
                    // TODO: Add meal functionality
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(recipes) { recipe in
                        Text(recipe.name)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
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
        } else if mealPlanStore.isEmpty {
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