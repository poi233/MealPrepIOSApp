//
//  MealPlanStore.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 8/3/25.
//  Refactored from 1821-line monolithic file into modular architecture.
//  Enhanced with structured logging and comprehensive documentation.
//

import SwiftUI
import Combine

/// Central state management for meal planning functionality
/// Coordinates meal plan data, AI generation, shopping lists, and nutrition analysis
/// Uses modular extensions for feature separation and maintainability
@MainActor
class MealPlanStore: ObservableObject {
    // MARK: - Published Properties - Core State
    @Published var mealPlans: [MealPlan] = []
    @Published var currentMealPlan: MealPlan?
    @Published var activeMealPlan: MealPlan?
    @Published var weeklyGrid = WeeklyMealGrid()
    @Published var selectedWeekStartDate = Date()
    @Published var isLoading = false
    @Published var errorMessage: String?

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

    // MARK: - Lightweight Meal Plan Support
    @Published var hasLightweightMeals = false
    @Published var lightweightDailyMeals: [LightweightDailyMeal] = []

    // MARK: - Service Dependencies
    let aiGenerationService = AIGenerationService()
    let localStorageService = MealPlanLocalStorageService()
    let shoppingListService = ShoppingListService()
    let nutritionAnalysisService = NutritionAnalysisService()

    let mealPlanService = MealPlanService()
    private var cancellables = Set<AnyCancellable>()
    let pageSize = 20

    // MARK: - Initialization

    /// Initialize MealPlanStore with default configuration
    /// Sets up observers and services but waits for authentication before loading data
    init() {
        AppLogger.info("Initializing MealPlanStore", category: .mealPlanning)
        setupSelectedWeek()
        setupNotificationObservers()
        setupServiceObservers()
        // Don't load initial data immediately - wait for user authentication
    }

    // MARK: - Initial Setup

    private func setupNotificationObservers() {
        // Listen for recipe deletion notifications
        NotificationCenter.default.addObserver(
            forName: .recipeDeleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let recipeId = notification.userInfo?[RecipeDeletionNotificationKeys.recipeId] as? String {
                Task { @MainActor in
                    self?.removeDeletedRecipe(recipeId: recipeId)
                }
            }
        }

        // Listen for user login to load cached data
        NotificationCenter.default.addObserver(
            forName: .userLoggedIn,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if notification.userInfo?["userID"] as? String != nil {
                AppLogger.info("User logged in, loading cached data", category: .mealPlanning)
                Task { @MainActor in
                    self?.loadInitialData()
                }
            }
        }

        // Listen for user logout to clear data
        NotificationCenter.default.addObserver(
            forName: .userLoggedOut,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.clearAllData()
            }
        }
    }

    private func setupSelectedWeek() {
        let now = Date()
        // Get the start of the current week (Monday) using our Monday-first calendar
        selectedWeekStartDate = localStorageService.normalizeWeekStartDate(now.startOfWeek())

        // Always initialize with an empty weekly grid for the selected week
        weeklyGrid = WeeklyMealGrid(weekStartDate: selectedWeekStartDate)
    }
    
    private func setupServiceObservers() {
        // Forward shopping list service changes to this store
        shoppingListService.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Forward nutrition analysis service changes to this store
        nutritionAnalysisService.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    /// Initialize data loading when user authentication is ready
    func initializeData() {
        loadInitialData()
    }

    private func loadInitialData() {
        // Clean up any invalid stored weeks first
        localStorageService.cleanupInvalidStoredWeeks()

        // Load local stored meal plan instead of fetching from backend
        loadLocalMealPlan()
    }

    // MARK: - Local Storage Integration

    func loadLocalMealPlan() {
        // Load meal plan for the currently selected week
        if let storedGrid = localStorageService.loadMealPlan(for: selectedWeekStartDate) {
            weeklyGrid = storedGrid
        } else {
            // No stored plan for this week, create an empty grid for the selected week
            weeklyGrid = WeeklyMealGrid(weekStartDate: selectedWeekStartDate)
        }
    }

    func saveLocalMealPlan() -> Result<Void, LocalStorageError> {
        return localStorageService.saveMealPlan(weeklyGrid)
    }

    // MARK: - Navigation Helper Methods

    var canNavigateToPreviousWeek: Bool {
        let calendar = Calendar.mondayFirst
        let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedWeekStartDate) ?? selectedWeekStartDate
        return isWithinAllowedWeekRange(previousWeek)
    }

    var canNavigateToNextWeek: Bool {
        let calendar = Calendar.mondayFirst
        let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedWeekStartDate) ?? selectedWeekStartDate
        return isWithinAllowedWeekRange(nextWeek)
    }

    func isWithinAllowedWeekRange(_ date: Date) -> Bool {
        let calendar = Calendar.mondayFirst
        let currentWeekStart = Date().startOfWeek()
        let weekDifference = calendar.dateComponents([.weekOfYear], from: currentWeekStart, to: date).weekOfYear ?? 0
        return abs(weekDifference) <= 4
    }

    // MARK: - Data Management

    func clearAllData() {
        mealPlans = []
        currentMealPlan = nil
        activeMealPlan = nil
        weeklyGrid = WeeklyMealGrid(weekStartDate: selectedWeekStartDate)
        recentMeals = []
        aiRecommendedRecipes = []
        hasLightweightMeals = false
        lightweightDailyMeals = []

        // Clear service data
        aiGenerationService.resetAIGenerationState()
        shoppingListService.clearShoppingList()
        nutritionAnalysisService.clearNutritionAnalysis()
        localStorageService.clearAllData()

        AppLogger.info("All data cleared", category: .mealPlanning)
    }

    private func removeDeletedRecipe(recipeId: String) {
        // Remove from recent meals
        recentMeals.removeAll { $0.id == recipeId }

        // Remove from AI recommendations
        aiRecommendedRecipes.removeAll { $0.id == recipeId }

        // Remove from weekly grid
        weeklyGrid.removeRecipe(recipeId)

        // Save changes
        _ = saveLocalMealPlan()

        AppLogger.info("Removed deleted recipe: \(recipeId)", category: .mealPlanning)
    }

    // MARK: - Computed Properties

    var hasAnyMealsThisWeek: Bool {
        weeklyGrid.hasAnyMeals
    }

    var mealsCountThisWeek: Int {
        weeklyGrid.totalMealsCount
    }

    var currentWeekDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let startDate = selectedWeekStartDate
        let endDate = Calendar.mondayFirst.date(byAdding: .day, value: 6, to: startDate) ?? startDate

        let startString = formatter.string(from: startDate)
        let endString = formatter.string(from: endDate)

        return "\(startString) - \(endString)"
    }

    var isCurrentWeek: Bool {
        let calendar = Calendar.mondayFirst
        let currentWeekStart = Date().startOfWeek()
        let normalizedCurrent = localStorageService.normalizeWeekStartDate(currentWeekStart)
        let normalizedSelected = localStorageService.normalizeWeekStartDate(selectedWeekStartDate)

        return calendar.isDate(normalizedCurrent, equalTo: normalizedSelected, toGranularity: .day)
    }
    
    // MARK: - Recipe Helper Methods
    
    func getAllRecipesForWeek() -> [Recipe] {
        var allRecipes: [Recipe] = []
        
        for dayMeal in weeklyGrid.dailyMeals {
            allRecipes.append(contentsOf: dayMeal.breakfast)
            allRecipes.append(contentsOf: dayMeal.lunch)
            allRecipes.append(contentsOf: dayMeal.dinner)
        }
        
        return allRecipes
    }
    
    func getAllUniqueRecipesForWeek() -> [Recipe] {
        let allRecipes = getAllRecipesForWeek()
        var uniqueRecipes: [Recipe] = []
        var seenIds = Set<String>()
        
        for recipe in allRecipes {
            if !seenIds.contains(recipe.id) {
                uniqueRecipes.append(recipe)
                seenIds.insert(recipe.id)
            }
        }
        
        return uniqueRecipes
    }
}

// MARK: - Service Integration Computed Properties

extension MealPlanStore {
    // AI Generation Service Properties
    var aiGenerationState: AIGenerationState {
        aiGenerationService.aiGenerationState
    }

    var previewMealPlan: MealPlan? {
        aiGenerationService.previewMealPlan
    }

    var previewWeeklyGrid: WeeklyMealGrid? {
        aiGenerationService.previewWeeklyGrid
    }

    var showingAIPreview: Bool {
        aiGenerationService.showingAIPreview
    }

    var isGenerating: Bool {
        aiGenerationService.isGenerating
    }

    // Shopping List Service Properties
    var shoppingList: [ShoppingListItem] {
        shoppingListService.shoppingList
    }

    var isLoadingShoppingList: Bool {
        shoppingListService.isLoadingShoppingList
    }

    // Nutrition Analysis Service Properties
    var nutritionAnalysis: MealPlanAnalysis? {
        get { nutritionAnalysisService.nutritionAnalysis }
        set {
            if newValue == nil {
                nutritionAnalysisService.clearNutritionAnalysis()
            } else {
                nutritionAnalysisService.nutritionAnalysis = newValue
            }
        }
    }

    var isAnalyzing: Bool {
        nutritionAnalysisService.isAnalyzing
    }
}