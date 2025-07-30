//
//  AIWeeklyPreviewView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/28/25.
//

import SwiftUI

/// AI Weekly Preview View - Shows AI-generated meal plan with editing capabilities
struct AIWeeklyPreviewView: View {
    // MARK: - Environment & State
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @EnvironmentObject var recipeStore: RecipeStore
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Workflow Integration
    var onApply: (() -> Void)? = nil
    var onRegenerate: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil
    
    // MARK: - Preview Data
    let generatedMealPlan: MealPlan
    @State private var previewGrid: WeeklyMealGrid
    @State private var nutritionSummary: NutritionSummary?
    
    // MARK: - UI State
    @State private var isApplying = false
    @State private var showingRecipeReplacement = false
    @State private var selectedMealSlot: MealSlotIdentifier?
    @State private var showingRegenerateOptions = false
    @State private var showingNutritionDetail = false
    
    // MARK: - Initialization
    init(generatedMealPlan: MealPlan) {
        self.generatedMealPlan = generatedMealPlan
        self._previewGrid = State(initialValue: WeeklyMealGrid(weekStartDate: generatedMealPlan.weekStartDate))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with plan description
                    planHeaderView
                    
                    // Nutrition Summary Card
                    if let nutrition = nutritionSummary {
                        nutritionSummaryCard(nutrition)
                    }
                    
                    // Weekly Meal Grid Preview
                    weeklyGridPreview
                    
                    // Action Buttons
                    actionButtonsView
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AI Meal Plan Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if let onCancel = onCancel {
                            onCancel()
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Regenerate") {
                        if let onRegenerate = onRegenerate {
                            onRegenerate()
                        } else {
                            showingRegenerateOptions = true
                        }
                    }
                    .foregroundColor(.primaryGreen)
                }
            }
            .onAppear {
                setupPreviewData()
                calculateNutritionSummary()
            }
            .sheet(isPresented: $showingRecipeReplacement) {
                if let slot = selectedMealSlot {
                    RecipeReplacementSheet(
                        mealSlot: slot,
                        currentRecipe: getCurrentRecipe(for: slot),
                        onReplace: { newRecipe in
                            replaceRecipe(in: slot, with: newRecipe)
                        }
                    )
                }
            }
            .actionSheet(isPresented: $showingRegenerateOptions) {
                regenerateOptionsActionSheet
            }
            .sheet(isPresented: $showingNutritionDetail) {
                if let nutrition = nutritionSummary {
                    NutritionDetailSheet(summary: nutrition)
                }
            }
        }
    }
    
    // MARK: - Plan Header View
    private var planHeaderView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Generated Meal Plan")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(weekDateRange)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // AI badge
                HStack(spacing: 4) {
                    Image(systemName: "brain")
                        .font(.caption)
                    Text("AI Generated")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primaryGreen.opacity(0.1))
                .foregroundColor(.primaryGreen)
                .cornerRadius(8)
            }
            
            if let description = generatedMealPlan.planDescription {
                Text(description)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .greenThemeCard()
    }
    
    // MARK: - Nutrition Summary Card
    private func nutritionSummaryCard(_ nutrition: NutritionSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Weekly Nutrition Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Details") {
                    showingNutritionDetail = true
                }
                .font(.callout)
                .foregroundColor(.primaryGreen)
            }
            
            // Daily average nutrition
            HStack(spacing: 20) {
                nutritionItem("Calories", value: "\(Int(nutrition.averageCaloriesPerDay))", unit: "cal/day")
                nutritionItem("Protein", value: "\(Int(nutrition.averageProteinPerDay))g", unit: "per day")
                nutritionItem("Carbs", value: "\(Int(nutrition.averageCarbsPerDay))g", unit: "per day")
                nutritionItem("Fat", value: "\(Int(nutrition.averageFatPerDay))g", unit: "per day")
            }
            
            // Nutrition balance indicators
            HStack(spacing: 12) {
                nutritionBalanceIndicator("Variety", score: nutrition.varietyScore)
                nutritionBalanceIndicator("Balance", score: nutrition.balanceScore)
                nutritionBalanceIndicator("Health", score: nutrition.healthScore)
            }
        }
        .greenThemeCard()
    }
    
    private func nutritionItem(_ label: String, value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func nutritionBalanceIndicator(_ label: String, score: Double) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 2)
                    .frame(width: 24, height: 24)
                
                Circle()
                    .trim(from: 0, to: score)
                    .stroke(scoreColor(score), lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(score * 100))")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor(score))
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 0.8 { return .primaryGreen }
        else if score >= 0.6 { return .warning }
        else { return .error }
    }
    
    // MARK: - Weekly Grid Preview
    private var weeklyGridPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Meal Plan")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            LazyVStack(spacing: 12) {
                ForEach(Array(previewGrid.dailyMeals.enumerated()), id: \.element.id) { dayIndex, dailyMeal in
                    DailyPreviewCard(
                        dailyMeal: dailyMeal,
                        dayIndex: dayIndex,
                        onMealSlotTapped: { mealType in
                            selectedMealSlot = MealSlotIdentifier(dayIndex: dayIndex, mealType: mealType)
                            showingRecipeReplacement = true
                        },
                        onDeleteMeal: { mealType, recipe in
                            deleteMeal(dayIndex: dayIndex, mealType: mealType, recipe: recipe)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            Button(action: {
                if let onApply = onApply {
                    onApply()
                } else {
                    applyToCurrentWeek()
                }
            }) {
                HStack {
                    if isApplying {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.headline)
                    }
                    
                    Text(isApplying ? "Applying..." : "Apply to Current Week")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .primaryGreenButton()
            .disabled(isApplying)
            
            Button("Save as Template") {
                // TODO: Implement save as template
            }
            .outlineGreenButton()
        }
    }
    
    // MARK: - Regenerate Options
    private var regenerateOptionsActionSheet: ActionSheet {
        ActionSheet(
            title: Text("Regenerate Options"),
            message: Text("What would you like to regenerate?"),
            buttons: [
                .default(Text("Regenerate Entire Week")) {
                    regenerateEntireWeek()
                },
                .default(Text("Regenerate Empty Slots Only")) {
                    regenerateEmptySlots()
                },
                .default(Text("Improve Nutrition Balance")) {
                    improveNutritionBalance()
                },
                .cancel()
            ]
        )
    }
    
    // MARK: - Helper Methods
    
    private var weekDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startDate = generatedMealPlan.weekStartDate
        let endDate = Calendar.current.date(byAdding: .day, value: 6, to: startDate) ?? startDate
        
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    private func setupPreviewData() {
        // Convert MealPlan to WeeklyMealGrid
        previewGrid = WeeklyMealGrid(weekStartDate: generatedMealPlan.weekStartDate)
        
        print("🔄 [AIWeeklyPreviewView] Setting up preview data...")
        print("📋 [AIWeeklyPreviewView] Has dailyMeals: \(generatedMealPlan.dailyMeals != nil)")
        print("📋 [AIWeeklyPreviewView] Has items: \(generatedMealPlan.items != nil)")
        
        // Handle AI-generated meal plans with dailyMeals
        if let dailyMeals = generatedMealPlan.dailyMeals {
            print("📋 [AIWeeklyPreviewView] Processing \(dailyMeals.count) daily meals...")
            
            for (dayIndex, dailyMeal) in dailyMeals.enumerated() {
                if dayIndex < previewGrid.dailyMeals.count {
                    print("📋 [AIWeeklyPreviewView] Day \(dayIndex) (\(dailyMeal.day)): \(dailyMeal.breakfast.count) breakfast, \(dailyMeal.lunch.count) lunch, \(dailyMeal.dinner.count) dinner")
                    
                    // Now dailyMeal contains Recipe objects directly, no conversion needed
                    previewGrid.dailyMeals[dayIndex].breakfast = dailyMeal.breakfast
                    previewGrid.dailyMeals[dayIndex].lunch = dailyMeal.lunch
                    previewGrid.dailyMeals[dayIndex].dinner = dailyMeal.dinner
                }
            }
            
            print("✅ [AIWeeklyPreviewView] Successfully loaded AI meal plan to preview grid")
            return
        }
        
        // Handle regular meal plans with items
        if let items = generatedMealPlan.items {
            print("📋 [AIWeeklyPreviewView] Processing \(items.count) meal plan items...")
            
            for item in items {
                guard let recipe = item.recipe,
                      item.dayOfWeek < previewGrid.dailyMeals.count else { continue }
                
                switch item.mealType.lowercased() {
                case "breakfast":
                    previewGrid.dailyMeals[item.dayOfWeek].breakfast.append(recipe)
                case "lunch":
                    previewGrid.dailyMeals[item.dayOfWeek].lunch.append(recipe)
                case "dinner":
                    previewGrid.dailyMeals[item.dayOfWeek].dinner.append(recipe)
                default:
                    break
                }
            }
        }
    }
    

    
    private func calculateNutritionSummary() {
        var totalCalories: Double = 0
        var totalProtein: Double = 0
        var totalCarbs: Double = 0
        var totalFat: Double = 0
        var totalRecipes: Int = 0
        
        for dailyMeal in previewGrid.dailyMeals {
            let allRecipes = dailyMeal.breakfast + dailyMeal.lunch + dailyMeal.dinner
            totalRecipes += allRecipes.count
            
            for recipe in allRecipes {
                if let nutrition = recipe.nutritionInfo {
                    totalCalories += Double(nutrition.calories ?? "0") ?? 0
                    totalProtein += Double(nutrition.protein ?? "0") ?? 0
                    totalCarbs += Double(nutrition.carbohydrates ?? "0") ?? 0
                    totalFat += Double(nutrition.fat ?? "0") ?? 0
                }
            }
        }
        
        // Calculate averages and scores
        let daysCount = 7.0
        nutritionSummary = NutritionSummary(
            totalCalories: totalCalories,
            totalProtein: totalProtein,
            totalCarbs: totalCarbs,
            totalFat: totalFat,
            averageCaloriesPerDay: totalCalories / daysCount,
            averageProteinPerDay: totalProtein / daysCount,
            averageCarbsPerDay: totalCarbs / daysCount,
            averageFatPerDay: totalFat / daysCount,
            varietyScore: calculateVarietyScore(),
            balanceScore: calculateBalanceScore(),
            healthScore: calculateHealthScore()
        )
    }
    
    private func calculateVarietyScore() -> Double {
        // Simple variety calculation based on unique recipes
        let allRecipes = previewGrid.dailyMeals.flatMap { [$0.breakfast, $0.lunch, $0.dinner].flatMap { $0 } }
        let uniqueRecipes = Set(allRecipes.map { $0.id })
        return min(1.0, Double(uniqueRecipes.count) / 15.0) // Assume 15+ unique recipes = 100% variety
    }
    
    private func calculateBalanceScore() -> Double {
        // Simple balance score - more sophisticated calculation could be implemented
        return 0.8 // Placeholder
    }
    
    private func calculateHealthScore() -> Double {
        // Simple health score based on variety and nutrition
        return min(1.0, (calculateVarietyScore() + calculateBalanceScore()) / 2.0)
    }
    
    private func getCurrentRecipe(for slot: MealSlotIdentifier) -> Recipe? {
        guard slot.dayIndex < previewGrid.dailyMeals.count else { return nil }
        
        let dailyMeal = previewGrid.dailyMeals[slot.dayIndex]
        let recipes: [Recipe]
        
        switch slot.mealType {
        case .breakfast:
            recipes = dailyMeal.breakfast
        case .lunch:
            recipes = dailyMeal.lunch
        case .dinner:
            recipes = dailyMeal.dinner
        }
        
        return recipes.first // For now, assume one recipe per slot
    }
    
    private func replaceRecipe(in slot: MealSlotIdentifier, with newRecipe: Recipe) {
        guard slot.dayIndex < previewGrid.dailyMeals.count else { return }
        
        switch slot.mealType {
        case .breakfast:
            previewGrid.dailyMeals[slot.dayIndex].breakfast = [newRecipe]
        case .lunch:
            previewGrid.dailyMeals[slot.dayIndex].lunch = [newRecipe]
        case .dinner:
            previewGrid.dailyMeals[slot.dayIndex].dinner = [newRecipe]
        }
        
        // Recalculate nutrition summary
        calculateNutritionSummary()
    }
    
    private func deleteMeal(dayIndex: Int, mealType: MealType, recipe: Recipe) {
        guard dayIndex < previewGrid.dailyMeals.count else { return }
        
        switch mealType {
        case .breakfast:
            previewGrid.dailyMeals[dayIndex].breakfast.removeAll { $0.id == recipe.id }
        case .lunch:
            previewGrid.dailyMeals[dayIndex].lunch.removeAll { $0.id == recipe.id }
        case .dinner:
            previewGrid.dailyMeals[dayIndex].dinner.removeAll { $0.id == recipe.id }
        }
        
        calculateNutritionSummary()
    }
    
    private func applyToCurrentWeek() {
        isApplying = true
        
        Task {
            // Apply the preview grid to the current week in meal plan store
            await MainActor.run {
                mealPlanStore.weeklyGrid = previewGrid
                
                // Save to local storage
                let saveResult = mealPlanStore.saveLocalMealPlan()
                if case .failure(let error) = saveResult {
                    print("❌ Failed to save meal plan: \(error)")
                }
            }
            
            await MainActor.run {
                isApplying = false
                dismiss()
            }
        }
    }
    
    private func regenerateEntireWeek() {
        // TODO: Implement regeneration through AI service
        print("🔄 Regenerating entire week...")
    }
    
    private func regenerateEmptySlots() {
        // TODO: Implement empty slot regeneration
        print("🔄 Regenerating empty slots...")
    }
    
    private func improveNutritionBalance() {
        // TODO: Implement nutrition balance improvement
        print("🔄 Improving nutrition balance...")
    }
}

// MARK: - Supporting Views

struct DailyPreviewCard: View {
    let dailyMeal: DailyMealSlots
    let dayIndex: Int
    let onMealSlotTapped: (MealType) -> Void
    let onDeleteMeal: (MealType, Recipe) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dailyMeal.day)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(dailyMeal.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Meal slots
            VStack(spacing: 8) {
                MealPreviewSlot(
                    title: "Breakfast",
                    recipes: dailyMeal.breakfast,
                    mealType: .breakfast,
                    onTap: { onMealSlotTapped(.breakfast) },
                    onDelete: { recipe in onDeleteMeal(.breakfast, recipe) }
                )
                
                MealPreviewSlot(
                    title: "Lunch",
                    recipes: dailyMeal.lunch,
                    mealType: .lunch,
                    onTap: { onMealSlotTapped(.lunch) },
                    onDelete: { recipe in onDeleteMeal(.lunch, recipe) }
                )
                
                MealPreviewSlot(
                    title: "Dinner",
                    recipes: dailyMeal.dinner,
                    mealType: .dinner,
                    onTap: { onMealSlotTapped(.dinner) },
                    onDelete: { recipe in onDeleteMeal(.dinner, recipe) }
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

struct MealPreviewSlot: View {
    let title: String
    let recipes: [Recipe]
    let mealType: MealType
    let onTap: () -> Void
    let onDelete: (Recipe) -> Void
    
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
        VStack(alignment: .leading, spacing: 8) {
            // Meal type header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: mealIcon)
                        .font(.caption)
                        .foregroundColor(mealColor)
                    
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: onTap) {
                    Image(systemName: recipes.isEmpty ? "plus.circle" : "pencil.circle")
                        .font(.caption)
                        .foregroundColor(.primaryGreen)
                }
            }
            
            // Recipe list or empty state
            if recipes.isEmpty {
                Button(action: onTap) {
                    HStack {
                        Text("Tap to add recipe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                ForEach(recipes) { recipe in
                    HStack {
                        Button(action: onTap) {
                            HStack {
                                Circle()
                                    .fill(mealColor.opacity(0.2))
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Image(systemName: "fork.knife")
                                            .font(.caption2)
                                            .foregroundColor(mealColor)
                                    )
                                
                                Text(recipe.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { onDelete(recipe) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.error)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Supporting Types

struct MealSlotIdentifier {
    let dayIndex: Int
    let mealType: MealType
}

struct NutritionSummary {
    let totalCalories: Double
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let averageCaloriesPerDay: Double
    let averageProteinPerDay: Double
    let averageCarbsPerDay: Double
    let averageFatPerDay: Double
    let varietyScore: Double
    let balanceScore: Double
    let healthScore: Double
}

// MARK: - Supporting Sheets

struct RecipeReplacementSheet: View {
    let mealSlot: MealSlotIdentifier
    let currentRecipe: Recipe?
    let onReplace: (Recipe) -> Void
    
    @EnvironmentObject var recipeStore: RecipeStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var isRegenerating = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                SearchBar(text: $searchText)
                    .padding()
                
                if isRegenerating {
                    VStack {
                        ProgressView()
                        Text("Generating new recipe...")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Recipe list
                    List(filteredRecipes) { recipe in
                        Button(action: {
                            onReplace(recipe)
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(recipe.name)
                                        .font(.callout)
                                        .fontWeight(.medium)
                                    
                                    if let calories = recipe.nutritionInfo?.calories {
                                        Text("\(calories) calories")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.right.circle")
                                    .foregroundColor(.primaryGreen)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle("Replace Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("AI Generate") {
                        generateNewRecipe()
                    }
                    .foregroundColor(.primaryGreen)
                }
            }
        }
        .onAppear {
            // Load recipes for replacement
            Task {
                await recipeStore.loadRecipes()
            }
        }
    }
    
    private var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return recipeStore.recipes
        } else {
            return recipeStore.recipes.filter { recipe in
                recipe.name.localizedCaseInsensitiveContains(searchText) ||
                recipe.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    private func generateNewRecipe() {
        isRegenerating = true
        
        // TODO: Implement AI recipe generation for specific meal type
        Task {
            // Simulate AI generation
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            await MainActor.run {
                isRegenerating = false
                // For now, use sample recipe
                onReplace(Recipe.sampleRecipe)
                dismiss()
            }
        }
    }
}

struct NutritionDetailSheet: View {
    let summary: NutritionSummary
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Daily averages
                VStack(alignment: .leading, spacing: 16) {
                    Text("Daily Averages")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        nutritionDetailItem("Calories", value: "\(Int(summary.averageCaloriesPerDay))", unit: "per day")
                        nutritionDetailItem("Protein", value: "\(Int(summary.averageProteinPerDay))g", unit: "per day")
                        nutritionDetailItem("Carbs", value: "\(Int(summary.averageCarbsPerDay))g", unit: "per day")
                        nutritionDetailItem("Fat", value: "\(Int(summary.averageFatPerDay))g", unit: "per day")
                    }
                }
                .greenThemeCard()
                
                // Weekly totals
                VStack(alignment: .leading, spacing: 16) {
                    Text("Weekly Totals")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        nutritionDetailItem("Calories", value: "\(Int(summary.totalCalories))", unit: "total")
                        nutritionDetailItem("Protein", value: "\(Int(summary.totalProtein))g", unit: "total")
                        nutritionDetailItem("Carbs", value: "\(Int(summary.totalCarbs))g", unit: "total")
                        nutritionDetailItem("Fat", value: "\(Int(summary.totalFat))g", unit: "total")
                    }
                }
                .greenThemeCard()
                
                // Quality scores
                VStack(alignment: .leading, spacing: 16) {
                    Text("Plan Quality")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 20) {
                        qualityScoreItem("Variety", score: summary.varietyScore)
                        qualityScoreItem("Balance", score: summary.balanceScore)
                        qualityScoreItem("Health", score: summary.healthScore)
                    }
                }
                .greenThemeCard()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Nutrition Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func nutritionDetailItem(_ label: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.callout)
                .foregroundColor(.secondary)
            
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func qualityScoreItem(_ label: String, score: Double) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: score)
                    .stroke(scoreColor(score), lineWidth: 4)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(score * 100))")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor(score))
            }
            
            Text(label)
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 0.8 { return .primaryGreen }
        else if score >= 0.6 { return .warning }
        else { return .error }
    }
}

// MARK: - Preview
#Preview {
    AIWeeklyPreviewView(generatedMealPlan: MealPlan(
        id: "preview-1",
        userId: "user-1",
        name: "AI Generated Plan",
        description: "Healthy weekly meal plan",
        weekStartDate: Date(),
        isActive: true,
        planDescription: "Balanced nutrition with variety",
        analysisText: nil as String?,
        items: [] as [MealPlanItem]?,
        itemsCount: 0,
        createdAt: Date(),
        updatedAt: Date()
    ))
    .environmentObject(MealPlanStore())
    .environmentObject(RecipeStore())
}