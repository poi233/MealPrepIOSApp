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
        selectedWeekStartDate = startOfWeek(for: Date())
        weeklyGrid = WeeklyMealGrid(weekStartDate: selectedWeekStartDate)
    }
    
    private func loadInitialData() {
        Task {
            await loadMealPlans()
            await loadActiveMealPlan()
            await loadWeeklyMealPlan()
        }
    }
    
    // MARK: - Meal Plan Loading
    
    func loadMealPlans(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            mealPlans = []
        }
        
        isLoading = !refresh && mealPlans.isEmpty
        errorMessage = nil
        
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
            errorMessage = error.localizedDescription
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
        errorMessage = nil
        
        do {
            currentMealPlan = try await mealPlanService.getMealPlan(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - AI Meal Plan Generation
    
    func generateMealPlan(preferences: MealPlanPreferences, description: String) async -> Bool {
        isGenerating = true
        errorMessage = nil
        
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
            errorMessage = error.localizedDescription
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
        errorMessage = nil
        
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
            errorMessage = error.localizedDescription
            isGenerating = false
            return false
        }
    }
    
    // MARK: - Meal Plan Analysis
    
    func analyzeMealPlan(id: String, analysisType: AnalysisType = .full) async -> Bool {
        isAnalyzing = true
        errorMessage = nil
        
        do {
            nutritionAnalysis = try await mealPlanService.analyzeMealPlan(id: id, analysisType: analysisType)
            isAnalyzing = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isAnalyzing = false
            return false
        }
    }
    
    func analyzeCurrentMealPlan() async -> Bool {
        guard let currentMealPlan = currentMealPlan else {
            errorMessage = "No meal plan selected"
            return false
        }
        
        return await analyzeMealPlan(id: currentMealPlan.id)
    }
    
    // MARK: - Shopping List Generation
    
    func generateShoppingList() async -> Bool {
        guard let currentMealPlan = currentMealPlan else {
            errorMessage = "No meal plan selected"
            return false
        }
        
        isLoadingShoppingList = true
        errorMessage = nil
        
        do {
            shoppingList = try await mealPlanService.generateShoppingList(mealPlan: currentMealPlan)
            isLoadingShoppingList = false
            return true
        } catch {
            errorMessage = error.localizedDescription
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
            if let weekMealPlan = try await mealPlanService.getCurrentWeekMealPlan() {
                activeMealPlan = weekMealPlan
                updateWeeklyGridFromMealPlan(weekMealPlan)
            } else {
                // No meal plan for current week, initialize empty grid
                weeklyGrid = WeeklyMealGrid(weekStartDate: selectedWeekStartDate)
            }
        } catch {
            errorMessage = error.localizedDescription
            weeklyGrid = WeeklyMealGrid(weekStartDate: selectedWeekStartDate)
        }
    }
    
    func loadActiveMealPlan() async {
        // Load the meal plan for the selected week
        await loadWeeklyMealPlan()
    }
    
    func navigateToWeek(_ direction: WeekDirection) async {
        let calendar = Calendar.current
        let newDate: Date
        
        switch direction {
        case .previous:
            newDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedWeekStartDate) ?? selectedWeekStartDate
        case .next:
            newDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedWeekStartDate) ?? selectedWeekStartDate
        case .current:
            newDate = startOfWeek(for: Date())
        }
        
        selectedWeekStartDate = newDate
        weeklyGrid = WeeklyMealGrid(weekStartDate: newDate)
        await loadWeeklyMealPlan()
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
                case "snack":
                    weeklyGrid.dailyMeals[dayIndex].snack.append(recipe)
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Meal Plan CRUD Operations
    
    func createMealPlan(_ request: CreateMealPlanRequest) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let newMealPlan = try await mealPlanService.createMealPlan(request)
            mealPlans.insert(newMealPlan, at: 0)
            currentMealPlan = newMealPlan
            totalCount += 1
            
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func updateMealPlan(id: String, updates: UpdateMealPlanRequest) async -> Bool {
        isLoading = true
        errorMessage = nil
        
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
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func deleteMealPlan(id: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
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
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func duplicateMealPlan(id: String, newWeekStartDate: Date) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let duplicatedMealPlan = try await mealPlanService.duplicateMealPlan(id: id, newWeekStartDate: newWeekStartDate)
            mealPlans.insert(duplicatedMealPlan, at: 0)
            totalCount += 1
            
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - Convenience Methods
    
    func getAllMealPlans() async {
        do {
            let allPlans = try await mealPlanService.getAllMealPlans()
            mealPlans = allPlans
            totalCount = allPlans.count
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Helper Methods
    
    private func startOfWeek(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
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
        errorMessage = nil
    }
    
    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}

// MARK: - Supporting Enums

enum WeekDirection {
    case previous, next, current
}