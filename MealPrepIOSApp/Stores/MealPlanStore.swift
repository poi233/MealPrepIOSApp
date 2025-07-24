//
//  MealPlanStore.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/20/25.
//

import SwiftUI
import Combine

@MainActor
class MealPlanStore: ObservableObject {
    // MARK: - Published Properties
    @Published var mealPlans: [MealPlan] = []
    @Published var currentMealPlan: MealPlan?
    @Published var activeMealPlan: MealPlan?
    @Published var weeklyGrid = WeeklyMealGrid()
    @Published var selectedWeekStartDate = Date()
    @Published var isLoading = false
    @Published var isGenerating = false
    @Published var isAnalyzing = false
    @Published var errorMessage: String?
    
    // Shopping list and nutrition
    @Published var shoppingList: [ShoppingListItem] = []
    @Published var nutritionAnalysis: MealPlanAnalysis?
    @Published var isLoadingShoppingList = false
    
    // Recent meals and AI recommendations
    @Published var recentMeals: [Recipe] = []
    @Published var aiRecommendedRecipes: [Recipe] = []
    
    // Pagination
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var hasMorePages = false
    @Published var totalCount = 0
    
    // UI State
    @Published var showingGenerationView = false
    @Published var showingAnalysisView = false
    
    private let mealPlanService = MealPlanService()
    private let aiService = AIService()
    private var cancellables = Set<AnyCancellable>()
    private let pageSize = 20
    
    init() {
        setupSelectedWeek()
        loadInitialData()
    }
    
    // MARK: - Initial Setup
    
    private func setupSelectedWeek() {
        let calendar = Calendar.current
        let now = Date()
        // Get the start of the current week (Sunday)
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        selectedWeekStartDate = weekInterval?.start ?? now
        
        // Always initialize with an empty weekly grid for the current week
        weeklyGrid = WeeklyMealGrid(weekStartDate: selectedWeekStartDate)
    }
    
    private func loadInitialData() {
        // Load local stored meal plan instead of fetching from backend
        loadLocalMealPlan()
    }
    
    // MARK: - Local Storage Methods
    
    private func loadLocalMealPlan() {
        // Load meal plan for the currently selected week
        if let storedGrid = LocalMealPlanStorage.shared.loadWeeklyMealPlan(for: selectedWeekStartDate) {
            weeklyGrid = storedGrid
            print("✅ Loaded meal plan from local storage for week \(formatSelectedWeekDate())")
        } else {
            // No stored plan for this week, create empty grid
            weeklyGrid = WeeklyMealGrid(weekStartDate: selectedWeekStartDate)
            print("📱 Created new empty meal plan grid for week \(formatSelectedWeekDate())")
        }
    }
    
    func saveLocalMealPlan() {
        // Save meal plan for the currently selected week
        LocalMealPlanStorage.shared.saveWeeklyMealPlan(for: selectedWeekStartDate, weeklyGrid)
        print("💾 Saved meal plan for week \(formatSelectedWeekDate())")
    }
    
    // MARK: - Helper Methods for Local Storage
    
    private func formatSelectedWeekDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: selectedWeekStartDate)
    }
    
    // MARK: - Navigation Helper Methods
    
    var canNavigateToPreviousWeek: Bool {
        let calendar = Calendar.current
        let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedWeekStartDate) ?? selectedWeekStartDate
        return isWithinAllowedWeekRange(previousWeek)
    }
    
    var canNavigateToNextWeek: Bool {
        let calendar = Calendar.current
        let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedWeekStartDate) ?? selectedWeekStartDate
        return isWithinAllowedWeekRange(nextWeek)
    }
    
    // MARK: - Meal Plan Loading
    
    func loadMealPlans(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            mealPlans = []
        }
        
        isLoading = !refresh && mealPlans.isEmpty
        
        do {
            let response = try await mealPlanService.getMealPlans(page: currentPage, pageSize: pageSize)
            
            if refresh || currentPage == 1 {
                mealPlans = response.results
            } else {
                mealPlans.append(contentsOf: response.results)
            }
            
            totalPages = response.totalPages
            totalCount = response.count
            hasMorePages = response.next != nil
            
            // Set current meal plan if none selected
            if currentMealPlan == nil && !mealPlans.isEmpty {
                currentMealPlan = mealPlans.first
            }
            
        } catch {
        }
        
        isLoading = false
    }
    
    func loadMoreMealPlans() async {
        guard hasMorePages && !isLoading else { return }
        
        currentPage += 1
        await loadMealPlans()
    }
    
    func refreshMealPlans() async {
        await loadMealPlans(refresh: true)
    }
    
    func loadMealPlan(id: String) async {
        isLoading = true
        
        do {
            currentMealPlan = try await mealPlanService.getMealPlan(id: id)
        } catch {
        }
        
        isLoading = false
    }
    
    // MARK: - AI Meal Plan Generation
    
    func generateMealPlan(preferences: MealPlanPreferences, description: String) async -> Bool {
        isGenerating = true
        
        do {
            let newMealPlan = try await mealPlanService.generateMealPlan(preferences: preferences, description: description)
            
            // Add to the beginning of the list
            mealPlans.insert(newMealPlan, at: 0)
            currentMealPlan = newMealPlan
            totalCount += 1
            
            // Update weekly grid if it's for the current week
            if Calendar.current.isDate(newMealPlan.weekStartDate, inSameDayAs: selectedWeekStartDate) {
                updateWeeklyGridFromMealPlan(newMealPlan)
            }
            
            isGenerating = false
            return true
        } catch {
            isGenerating = false
            return false
        }
    }
    
    func generateCustomMealPlan(
        description: String,
        dietType: DietType? = nil,
        allergies: [String] = [],
        dislikes: [String] = [],
        calorieTarget: Int? = nil,
        weekStartDate: Date? = nil,
        additionalRequirements: String? = nil
    ) async -> Bool {
        isGenerating = true
        
        do {
            let newMealPlan = try await mealPlanService.generateCustomMealPlan(
                description: description,
                dietType: dietType,
                allergies: allergies,
                dislikes: dislikes,
                calorieTarget: calorieTarget,
                weekStartDate: weekStartDate ?? selectedWeekStartDate,
                additionalRequirements: additionalRequirements
            )
            
            mealPlans.insert(newMealPlan, at: 0)
            currentMealPlan = newMealPlan
            totalCount += 1
            
            if Calendar.current.isDate(newMealPlan.weekStartDate, inSameDayAs: selectedWeekStartDate) {
                updateWeeklyGridFromMealPlan(newMealPlan)
            }
            
            isGenerating = false
            return true
        } catch {
            isGenerating = false
            return false
        }
    }
    
    // MARK: - Meal Plan Analysis
    
    func analyzeMealPlan(id: String, analysisType: AnalysisType = .full) async -> Bool {
        isAnalyzing = true
        
        do {
            nutritionAnalysis = try await mealPlanService.analyzeMealPlan(id: id, analysisType: analysisType)
            isAnalyzing = false
            return true
        } catch {
            isAnalyzing = false
            return false
        }
    }
    
    func analyzeCurrentMealPlan() async -> Bool {
        guard let currentMealPlan = currentMealPlan else {
            return false
        }
        
        return await analyzeMealPlan(id: currentMealPlan.id)
    }
    
    // MARK: - Shopping List Generation
    
    func generateShoppingList() async -> Bool {
        guard let currentMealPlan = currentMealPlan else {
            return false
        }
        
        isLoadingShoppingList = true
        
        do {
            shoppingList = try await mealPlanService.generateShoppingList(mealPlan: currentMealPlan)
            isLoadingShoppingList = false
            return true
        } catch {
            isLoadingShoppingList = false
            return false
        }
    }
    
    func toggleShoppingListItem(_ item: ShoppingListItem) {
        if let index = shoppingList.firstIndex(where: { $0.id == item.id }) {
            shoppingList[index] = ShoppingListItem(
                ingredient: item.ingredient,
                amount: item.amount,
                unit: item.unit,
                recipes: item.recipes,
                isCompleted: !item.isCompleted
            )
        }
    }
    
    // MARK: - Weekly Grid Management
    
    func loadWeeklyMealPlan() async {
        do {
            // Try to get meal plan for the selected week
            let weekMealPlan = try await mealPlanService.getMealPlanForWeek(startDate: selectedWeekStartDate)
            
            if let mealPlan = weekMealPlan {
                activeMealPlan = mealPlan
                updateWeeklyGridFromMealPlan(mealPlan)
            } else {
                // No meal plan for this week, but still show empty grid
                activeMealPlan = nil
                weeklyGrid = WeeklyMealGrid(weekStartDate: selectedWeekStartDate)
            }
        } catch {
            // On error, show empty grid
            activeMealPlan = nil
            weeklyGrid = WeeklyMealGrid(weekStartDate: selectedWeekStartDate)
        }
    }
    
    func loadActiveMealPlan() async {
        // Load the meal plan for the selected week
        await loadWeeklyMealPlan()
    }
    
    func navigateToWeek(_ direction: WeekDirection) async {
        // First save current week's data
        saveLocalMealPlan()
        
        let calendar = Calendar.current
        let newDate: Date
        
        switch direction {
        case .previous:
            newDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedWeekStartDate) ?? selectedWeekStartDate
        case .next:
            newDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedWeekStartDate) ?? selectedWeekStartDate
        case .current:
            let calendar = Calendar.current
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            newDate = calendar.date(from: components) ?? Date()
        }
        
        // Check if navigation is within allowed range (current +/- 4 weeks)
        if !isWithinAllowedWeekRange(newDate) {
            print("⚠️ Navigation blocked: Week \(formatWeekDate(newDate)) is outside allowed range")
            return
        }
        
        selectedWeekStartDate = newDate
        
        // Load meal plan for new week from local storage or create empty
        loadLocalMealPlan()
    }
    
    // MARK: - Week Range Validation
    
    private func isWithinAllowedWeekRange(_ weekStartDate: Date) -> Bool {
        let calendar = Calendar.current
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        
        // Calculate the difference in weeks
        let weekDifference = calendar.dateComponents([.weekOfYear], from: currentWeekStart, to: weekStartDate).weekOfYear ?? 0
        
        // Allow current week plus/minus 4 weeks (total range: 9 weeks)
        return abs(weekDifference) <= 4
    }
    
    private func formatWeekDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func updateWeeklyGridFromMealPlan(_ mealPlan: MealPlan) {
        // Convert meal plan to weekly grid format
        weeklyGrid = WeeklyMealGrid(weekStartDate: mealPlan.weekStartDate)
        
        // Process meal plan items if they exist
        guard let items = mealPlan.items else { return }
        
        // Group items by day and meal type
        for item in items {
            let dayIndex = item.dayOfWeek
            if dayIndex < weeklyGrid.dailyMeals.count, let recipe = item.recipe {
                switch item.mealType.lowercased() {
                case "breakfast":
                    weeklyGrid.dailyMeals[dayIndex].breakfast.append(recipe)
                case "lunch":
                    weeklyGrid.dailyMeals[dayIndex].lunch.append(recipe)
                case "dinner":
                    weeklyGrid.dailyMeals[dayIndex].dinner.append(recipe)
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Meal Plan CRUD Operations
    
    func createMealPlan(_ request: CreateMealPlanRequest) async -> Bool {
        isLoading = true
        
        do {
            let newMealPlan = try await mealPlanService.createMealPlan(request)
            mealPlans.insert(newMealPlan, at: 0)
            currentMealPlan = newMealPlan
            totalCount += 1
            
            isLoading = false
            return true
        } catch {
            isLoading = false
            return false
        }
    }
    
    func updateMealPlan(id: String, updates: UpdateMealPlanRequest) async -> Bool {
        isLoading = true
        
        do {
            let updatedMealPlan = try await mealPlanService.updateMealPlan(id: id, updates: updates)
            
            // Update in the list
            if let index = mealPlans.firstIndex(where: { $0.id == id }) {
                mealPlans[index] = updatedMealPlan
            }
            
            // Update current meal plan if it's the same
            if currentMealPlan?.id == id {
                currentMealPlan = updatedMealPlan
            }
            
            isLoading = false
            return true
        } catch {
            isLoading = false
            return false
        }
    }
    
    func deleteMealPlan(id: String) async -> Bool {
        isLoading = true
        
        do {
            try await mealPlanService.deleteMealPlan(id: id)
            
            // Remove from the list
            mealPlans.removeAll { $0.id == id }
            totalCount = max(0, totalCount - 1)
            
            // Clear current meal plan if it's the same
            if currentMealPlan?.id == id {
                currentMealPlan = mealPlans.first
            }
            
            isLoading = false
            return true
        } catch {
            isLoading = false
            return false
        }
    }
    
    func duplicateMealPlan(id: String, newWeekStartDate: Date) async -> Bool {
        isLoading = true
        
        do {
            let duplicatedMealPlan = try await mealPlanService.duplicateMealPlan(id: id, newWeekStartDate: newWeekStartDate)
            mealPlans.insert(duplicatedMealPlan, at: 0)
            totalCount += 1
            
            isLoading = false
            return true
        } catch {
            isLoading = false
            return false
        }
    }
    
    // MARK: - Meal Management Methods
    
    func findMealPlanItem(recipeId: String, dayOfWeek: Int, mealType: MealType) -> MealPlanItem? {
        guard let activePlan = activeMealPlan else { return nil }
        return activePlan.items?.first { item in
            item.recipe?.id == recipeId &&
            item.dayOfWeek == dayOfWeek &&
            item.mealType == mealType.rawValue
        }
    }
    
    func addMealToWeek(recipe: Recipe, dayOfWeek: Int, mealType: MealType, servingSize: Double = 1.0) async {
        // Ensure we're on the main actor for UI updates
        await MainActor.run {
            // Add meal to local weekly grid directly
            guard dayOfWeek < weeklyGrid.dailyMeals.count else {
                errorMessage = "Invalid day of week: \(dayOfWeek)"
                return
            }
            
            // Add recipe to appropriate meal type
            switch mealType {
            case .breakfast:
                weeklyGrid.dailyMeals[dayOfWeek].breakfast.append(recipe)
            case .lunch:
                weeklyGrid.dailyMeals[dayOfWeek].lunch.append(recipe)
            case .dinner:
                weeklyGrid.dailyMeals[dayOfWeek].dinner.append(recipe)
            }
            
            print("✅ Added \(recipe.name) to \(mealType.rawValue) for day \(dayOfWeek)")
        }
        
        // Save to local storage (this can be done off main thread)
        saveLocalMealPlan()
        
        // Add to recent meals
        await addToRecentMeals(recipe)
    }
    
    // MARK: - Create Meal Plan for Current Week
    
    private func createMealPlanForCurrentWeek() async {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        
        let request = CreateMealPlanRequest(
            name: "Week of \(DateFormatter.shortDate.string(from: weekStart))",
            description: "Automatically created meal plan for the current week",
            startDate: weekStart,
            endDate: weekEnd,
            items: nil, // No items initially
            preferences: MealPlanPreferences(
                targetCalories: nil,
                dietaryRestrictions: nil,
                excludeIngredients: nil,
                cuisinePreferences: nil,
                mealTypes: MealType.allCases,
                maxPrepTime: nil,
                budgetLevel: nil
            )
        )
        
        do {
            let newMealPlan = try await mealPlanService.createMealPlan(request)
            activeMealPlan = newMealPlan
            
            // Also add to the meal plans list if not already there
            if !mealPlans.contains(where: { $0.id == newMealPlan.id }) {
                mealPlans.insert(newMealPlan, at: 0)
                totalCount += 1
            }
            
            // Update the weekly grid
            updateWeeklyGridFromMealPlan(newMealPlan)
            
        } catch {
            errorMessage = "Failed to create meal plan for current week: \(error.localizedDescription)"
        }
    }
    
    func addCustomMealToWeek(name: String, calories: Double, dayOfWeek: Int, mealType: MealType) async {
        // Create a temporary custom recipe
        let customRecipe = Recipe(
            id: UUID().uuidString,
            name: name,
            description: "Custom meal",
            ingredients: [],
            instructions: "Custom meal added manually",
            nutritionInfo: NutritionInfo(calories: String(Int(calories))),
            cuisine: nil,
            prepTime: 0,
            cookTime: 0,
            difficulty: .easy,
            avgRating: 0.0,
            ratingCount: 0,
            imageUrl: nil,
            tags: ["custom"],
            createdByUser: "system",
            createdByUserId: "system",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        await addMealToWeek(recipe: customRecipe, dayOfWeek: dayOfWeek, mealType: mealType)
    }
    
    func removeMealFromPlan(mealPlanItem: MealPlanItem) async {
        guard let mealPlan = activeMealPlan else { return }
        
        isLoading = true
        
        do {
            try await mealPlanService.removeMealPlanItem(
                mealPlanId: mealPlan.id,
                dayOfWeek: mealPlanItem.dayOfWeek,
                mealType: MealType(rawValue: mealPlanItem.mealType) ?? .breakfast
            )
            
            // Update local state
            await loadWeeklyMealPlan()
            
        } catch {
            errorMessage = "Failed to remove meal: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func updateMealServingSize(mealPlanItem: MealPlanItem, newServingSize: Double) async {
        guard let mealPlan = activeMealPlan else { return }
        
        isLoading = true
        
        do {
            let _ = try await mealPlanService.updateMealPlanItem(
                mealPlanId: mealPlan.id,
                itemId: String(mealPlanItem.id ?? 0),
                servingSize: newServingSize
            )
            
            // Update local state
            await loadWeeklyMealPlan()
            
        } catch {
            errorMessage = "Failed to update serving size: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func moveMeal(from item: MealPlanItem, toDayOfWeek: Int, toMealType: MealType) async {
        guard let mealPlan = activeMealPlan else { return }
        
        isLoading = true
        
        do {
            // Remove from old location
            try await mealPlanService.removeMealPlanItem(
                mealPlanId: mealPlan.id,
                dayOfWeek: item.dayOfWeek,
                mealType: MealType(rawValue: item.mealType) ?? .breakfast
            )
            
            // Add to new location
            if let recipe = item.recipe {
                let _ = try await mealPlanService.addMealPlanItem(
                    mealPlanId: mealPlan.id,
                    recipeId: recipe.id,
                    dayOfWeek: toDayOfWeek,
                    mealType: toMealType,
                    servingSize: 1.0
                )
            }
            
            // Update local state
            await loadWeeklyMealPlan()
            
        } catch {
            errorMessage = "Failed to move meal: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func duplicateMeal(mealPlanItem: MealPlanItem, toDayOfWeek: Int, toMealType: MealType) async {
        guard let _ = activeMealPlan,
              let recipe = mealPlanItem.recipe else { return }
        
        await addMealToWeek(
            recipe: recipe,
            dayOfWeek: toDayOfWeek,
            mealType: toMealType,
            servingSize: 1.0
        )
    }
    
    // MARK: - Recent Meals Management
    
    func addToRecentMeals(_ recipe: Recipe) async {
        // Add to beginning and limit to 10 items
        recentMeals.removeAll { $0.id == recipe.id }
        recentMeals.insert(recipe, at: 0)
        recentMeals = Array(recentMeals.prefix(10))
    }
    
    // MARK: - AI Recommendations
    
    func loadAIRecommendations(for mealType: MealType) async {
        // TODO: Implement AI recommendations when AIService supports this method
        // For now, return sample recommendations
        await MainActor.run {
            aiRecommendedRecipes = [Recipe.sampleRecipe]
        }
    }
    
    // MARK: - Batch Operations
    
    func copyMealsFromPlan(_ sourcePlan: MealPlan) async {
        guard let targetPlan = activeMealPlan,
              let sourceItems = sourcePlan.items else { return }
        
        isLoading = true
        
        do {
            // Clear existing meals first
            await clearAllMealsForWeek()
            
            // Copy each meal item
            for item in sourceItems {
                if let recipe = item.recipe {
                    if let mealType = MealType(rawValue: item.mealType) {
                        try await mealPlanService.addMealPlanItem(
                            mealPlanId: targetPlan.id,
                            recipeId: recipe.id,
                            dayOfWeek: item.dayOfWeek,
                            mealType: mealType,
                            servingSize: 1.0
                        )
                    }
                }
            }
            
            // Refresh the weekly view
            await loadWeeklyMealPlan()
            
        } catch {
            errorMessage = "Failed to copy meals: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func generateWeekWithAI() async {
        guard let mealPlan = activeMealPlan else { return }
        
        isLoading = true
        
        do {
            // Generate AI recommendations for empty slots
            let emptySlots = findEmptyMealSlots()
            
            for slot in emptySlots {
                // TODO: Replace with actual AI service call
                let recommendations = [Recipe.sampleRecipe]
                
                if let recipe = recommendations.first {
                    let _ = try await mealPlanService.addMealPlanItem(
                        mealPlanId: mealPlan.id,
                        recipeId: recipe.id,
                        dayOfWeek: slot.dayOfWeek,
                        mealType: slot.mealType,
                        servingSize: 1.0
                    )
                }
            }
            
            await loadWeeklyMealPlan()
            
        } catch {
            errorMessage = "Failed to generate week with AI: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func clearAllMealsForWeek() async {
        guard let mealPlan = activeMealPlan,
              let items = mealPlan.items else { return }
        
        isLoading = true
        
        do {
            // Remove all meal items
            for item in items {
                if let mealType = MealType(rawValue: item.mealType) {
                    try await mealPlanService.removeMealPlanItem(
                        mealPlanId: mealPlan.id,
                        dayOfWeek: item.dayOfWeek,
                        mealType: mealType
                    )
                }
            }
            
            await loadWeeklyMealPlan()
            
        } catch {
            errorMessage = "Failed to clear meals: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func duplicateWeekToPlan(_ sourcePlan: MealPlan, weekStartDate: Date) async {
        guard let sourceItems = sourcePlan.items else { return }
        
        isLoading = true
        
        do {
            // Create new meal plan for target week
            let newPlanRequest = CreateMealPlanRequest(
                name: "\(sourcePlan.name) (Copy)",
                description: sourcePlan.description,
                startDate: weekStartDate,
                endDate: Calendar.current.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate,
                items: nil, // Items will be copied separately
                preferences: MealPlanPreferences(
                    targetCalories: nil,
                    dietaryRestrictions: nil,
                    excludeIngredients: nil,
                    cuisinePreferences: nil,
                    mealTypes: MealType.allCases,
                    maxPrepTime: nil,
                    budgetLevel: nil
                )
            )
            
            let newPlan = try await mealPlanService.createMealPlan(newPlanRequest)
            
            // Copy all meal items
            for item in sourceItems {
                if let recipe = item.recipe {
                    try await mealPlanService.addMealPlanItem(
                        mealPlanId: newPlan.id,
                        recipeId: recipe.id,
                        dayOfWeek: item.dayOfWeek,
                        mealType: MealType(rawValue: item.mealType) ?? MealType.breakfast,
                        servingSize: 1.0
                    )
                }
            }
            
            // Add to meal plans list
            mealPlans.insert(newPlan, at: 0)
            totalCount += 1
            
        } catch {
            errorMessage = "Failed to duplicate week: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func generateShoppingListForWeek() async {
        guard let mealPlan = activeMealPlan else { return }
        
        isLoadingShoppingList = true
        
        do {
            let generatedList = try await mealPlanService.generateShoppingList(mealPlan: mealPlan)
            shoppingList = generatedList
        } catch {
            errorMessage = "Failed to generate shopping list: \(error.localizedDescription)"
        }
        
        isLoadingShoppingList = false
    }
    
    // MARK: - Helper Methods for Batch Operations
    
    private func findEmptyMealSlots() -> [MealSlot] {
        var emptySlots: [MealSlot] = []
        let allMealTypes = MealType.allCases
        
        for dayOfWeek in 0..<7 {
            for mealType in allMealTypes {
                // Check if this slot is empty
                let hasExistingMeal = activeMealPlan?.items?.contains { item in
                    item.dayOfWeek == dayOfWeek && item.mealType == mealType.rawValue
                } ?? false
                
                if !hasExistingMeal {
                    emptySlots.append(MealSlot(dayOfWeek: dayOfWeek, mealType: mealType))
                }
            }
        }
        
        return emptySlots
    }
    
    // MARK: - Convenience Methods
    
    func getAllMealPlans() async {
        do {
            let allPlans = try await mealPlanService.getAllMealPlans()
            await MainActor.run {
                mealPlans = allPlans
                totalCount = allPlans.count
            }
        } catch {
            // Handle error silently for now
        }
    }
    
    // MARK: - Computed Properties
    
    var isEmpty: Bool {
        mealPlans.isEmpty && !isLoading
    }
    
    var hasCurrentMealPlan: Bool {
        currentMealPlan != nil
    }
    
    var statusText: String {
        if isLoading {
            return "Loading meal plans..."
        } else if isEmpty {
            return "No meal plans available"
        } else {
            return "\(totalCount) meal plan\(totalCount == 1 ? "" : "s")"
        }
    }
    
    // MARK: - Error Handling
    
    func clearError() {
    }
    
    func handleError(_ error: Error) {
    }
}

// MARK: - Supporting Types

struct MealSlot {
    let dayOfWeek: Int
    let mealType: MealType
}

// MARK: - Supporting Enums

enum WeekDirection {
    case previous, next, current
}

// MARK: - Extensions

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}
