//
//  MealPlanStore.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/20/25.
//

import SwiftUI
import Combine

// MARK: - AI Generation State
enum AIGenerationState {
    case idle
    case generating
    case previewing
    case confirming
    case error(String)
    
    var isLoading: Bool {
        switch self {
        case .generating, .confirming:
            return true
        default:
            return false
        }
    }
    
    var canPreview: Bool {
        if case .previewing = self {
            return true
        }
        return false
    }
    
    var canConfirm: Bool {
        if case .previewing = self {
            return true
        }
        return false
    }
}

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
    
    // MARK: - AI Generation State Management
    @Published var aiGenerationState: AIGenerationState = .idle
    @Published var previewMealPlan: MealPlan?
    @Published var previewWeeklyGrid: WeeklyMealGrid?
    @Published var aiGenerationError: String?
    @Published var showingAIPreview = false
    
    private let mealPlanService = MealPlanService()
    private let aiService = AIService()
    private var cancellables = Set<AnyCancellable>()
    private let pageSize = 20
    
    init() {
        setupSelectedWeek()
        setupNotificationObservers()
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
                self?.removeDeletedRecipe(recipeId: recipeId)
            }
        }
        
        // Listen for user login to load cached data
        NotificationCenter.default.addObserver(
            forName: .userLoggedIn,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let userID = notification.userInfo?["userID"] as? String {
                print("📥 [MealPlanStore] User logged in (\(userID)), loading cached data")
                self?.loadInitialData()
            }
        }
        
        // Listen for user logout to clear data
        NotificationCenter.default.addObserver(
            forName: .userLoggedOut,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearAllData()
        }
    }
    
    private func setupSelectedWeek() {
        let now = Date()
        // Get the start of the current week (Monday) using our Monday-first calendar
        selectedWeekStartDate = normalizeWeekStartDate(now.startOfWeek())
        
        // Always initialize with an empty weekly grid for the current week
        weeklyGrid = WeeklyMealGrid(weekStartDate: selectedWeekStartDate)
    }
    
    /// Normalize week start date to remove time components and ensure consistency
    private func normalizeWeekStartDate(_ date: Date) -> Date {
        let calendar = Calendar.mondayFirst
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: components) ?? date
    }
    
    /// Initialize data loading when user authentication is ready
    func initializeData() {
        loadInitialData()
    }
    
    private func loadInitialData() {
        // Clean up any invalid stored weeks first
        cleanupInvalidStoredWeeks()
        
        // Load local stored meal plan instead of fetching from backend
        loadLocalMealPlan()
    }
    
    /// Clean up stored weeks that are outside the allowed range
    private func cleanupInvalidStoredWeeks() {
        let calendar = Calendar.mondayFirst
        let currentWeekStart = Date().startOfWeek()
        
        let storage = LocalMealPlanStorage.shared
        let storedWeeks = storage.getAllStoredWeeks()
        
        for week in storedWeeks {
            let weekDifference = calendar.dateComponents([.weekOfYear], from: currentWeekStart, to: week).weekOfYear ?? 0
            if abs(weekDifference) > 4 {
                storage.clearMealPlan(for: week)
            }
        }
    }
    
    // MARK: - Local Storage Methods
    
    private func loadLocalMealPlan() {
        // Load meal plan for the currently selected week
        if let storedGrid = LocalMealPlanStorage.shared.loadWeeklyMealPlan(for: selectedWeekStartDate) {
            weeklyGrid = storedGrid
        } else {
            // No stored plan for this week, create empty grid
            weeklyGrid = WeeklyMealGrid(weekStartDate: selectedWeekStartDate)
        }
    }
    
    func saveLocalMealPlan() -> Result<Void, LocalStorageError> {
        return LocalMealPlanStorage.shared.saveWeeklyMealPlan(for: selectedWeekStartDate, weeklyGrid)
    }
    
    // MARK: - Helper Methods for Local Storage
    
    private func formatSelectedWeekDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: selectedWeekStartDate)
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
    
    /// Generate a weekly meal plan with AI and show preview
    func generateWeeklyMealPlan(
        description: String,
        dietType: DietType? = nil,
        allergies: [String] = [],
        dislikes: [String] = [],
        calorieTarget: Int? = nil,
        additionalRequirements: String? = nil
    ) async {
        await MainActor.run {
            aiGenerationState = .generating
            aiGenerationError = nil
            previewMealPlan = nil
            previewWeeklyGrid = nil
        }
        
        do {
            // Prepare dietary preferences
            var dietaryPreferences: [String: String] = [:]
            if let dietType = dietType {
                dietaryPreferences["dietType"] = dietType.rawValue
            }
            
            // Create generation request
            let request = GenerateMealPlanRequest(
                planDescription: description,
                dietaryPreferences: dietaryPreferences.isEmpty ? nil : dietaryPreferences,
                allergies: allergies.isEmpty ? nil : allergies,
                dislikes: dislikes.isEmpty ? nil : dislikes,
                calorieTarget: calorieTarget,
                weekStartDate: selectedWeekStartDate,
                additionalRequirements: additionalRequirements
            )
            
            // Generate meal plan using AI service
            let generatedPlan = try await aiService.generateMealPlan(request)
            
            await MainActor.run {
                // Store the preview meal plan
                previewMealPlan = generatedPlan
                
                // Convert to weekly grid for preview
                previewWeeklyGrid = convertMealPlanToWeeklyGrid(generatedPlan)
                
                // Update state to previewing
                aiGenerationState = .previewing
                showingAIPreview = true
                
                print("✅ [MealPlanStore] AI meal plan generated successfully for preview")
            }
            
        } catch {
            await MainActor.run {
                let errorMessage = "Failed to generate meal plan: \(error.localizedDescription)"
                aiGenerationState = .error(errorMessage)
                aiGenerationError = errorMessage
                
                print("❌ [MealPlanStore] AI meal plan generation failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Confirm and apply the preview meal plan to current week
    func confirmPreviewMealPlan() async {
        print("🚀 [MealPlanStore] confirmPreviewMealPlan called")
        print("🔍 [MealPlanStore] Initial state: \(aiGenerationState)")
        print("🔍 [MealPlanStore] Preview meal plan exists: \(previewMealPlan != nil)")
        print("🔍 [MealPlanStore] Preview weekly grid exists: \(previewWeeklyGrid != nil)")
        print("🔍 [MealPlanStore] Thread: \(Thread.isMainThread ? "Main" : "Background")")
        
        guard let preview = previewMealPlan else {
            print("❌ [MealPlanStore] No preview meal plan available")
            await MainActor.run {
                aiGenerationError = "No preview available to confirm"
                aiGenerationState = .error("No preview available to confirm")
            }
            return
        }
        
        guard let previewGrid = previewWeeklyGrid else {
            print("❌ [MealPlanStore] No preview weekly grid available")
            await MainActor.run {
                aiGenerationError = "No preview grid available to confirm"
                aiGenerationState = .error("No preview grid available to confirm")
            }
            return
        }
        
        guard case .previewing = aiGenerationState else {
            print("❌ [MealPlanStore] Invalid state for confirmation: \(aiGenerationState)")
            await MainActor.run {
                aiGenerationError = "Invalid state for meal plan confirmation"
                aiGenerationState = .error("Invalid state for meal plan confirmation")
            }
            return
        }
        
        print("✅ [MealPlanStore] Prerequisites met, proceeding with confirmation")
        print("🔍 [MealPlanStore] Preview meal plan name: \(preview.name)")
        print("🔍 [MealPlanStore] Preview daily meals count: \(preview.dailyMeals?.count ?? 0)")
        
        await MainActor.run {
            print("🔄 [MealPlanStore] Setting state to confirming")
            let previousState = aiGenerationState
            aiGenerationState = .confirming
            print("🔍 [MealPlanStore] State changed from \(previousState) to \(aiGenerationState)")
        }
        
        do {
            print("🔄 [MealPlanStore] Confirming preview meal plan: creating all recipes...")
            print("🔍 [MealPlanStore] Current state at start: \(aiGenerationState)")
            
            // CRITICAL: Create all recipes in the backend database before applying
            let updatedMealPlan = try await createAllRecipesInMealPlan(preview)
            print("✅ [MealPlanStore] Successfully created all recipes in meal plan")
            
            // Convert the updated meal plan to weekly grid
            let updatedWeeklyGrid = convertMealPlanToWeeklyGrid(updatedMealPlan)
            print("✅ [MealPlanStore] Successfully converted meal plan to weekly grid")
            
            // Apply the updated preview to current weekly grid
            await MainActor.run {
                print("🔄 [MealPlanStore] Applying updated meal plan to current state...")
                weeklyGrid = updatedWeeklyGrid
                previewMealPlan = updatedMealPlan  // Update preview with created recipes
                previewWeeklyGrid = updatedWeeklyGrid
                print("✅ [MealPlanStore] Applied updated meal plan to current state")
                print("🔍 [MealPlanStore] Current state after applying: \(aiGenerationState)")
            }
            
            // Save to local storage with proper recipe IDs
            print("🔄 [MealPlanStore] Saving meal plan to local storage...")
            let saveResult = saveLocalMealPlan()
            if case .failure(let error) = saveResult {
                print("❌ [MealPlanStore] Failed to save to local storage: \(error)")
                throw error
            }
            print("✅ [MealPlanStore] Successfully saved meal plan to local storage")
            
            // Add to meal plans list if not already there
            await MainActor.run {
                print("🔄 [MealPlanStore] Finalizing meal plan application...")
                if !mealPlans.contains(where: { $0.id == updatedMealPlan.id }) {
                    mealPlans.insert(updatedMealPlan, at: 0)
                    totalCount += 1
                    print("✅ [MealPlanStore] Added meal plan to list")
                }
                
                // Update current meal plan with the version that has created recipes
                currentMealPlan = updatedMealPlan
                activeMealPlan = updatedMealPlan
                print("✅ [MealPlanStore] Updated current and active meal plans")
                
                print("🔄 [MealPlanStore] About to set state to idle...")
                print("🔍 [MealPlanStore] Current state before setting to idle: \(aiGenerationState)")
                
                // IMPORTANT: Set state to idle to signal successful completion
                aiGenerationState = .idle
                print("✅ [MealPlanStore] Set aiGenerationState to .idle")
                print("🔍 [MealPlanStore] Current state after setting to idle: \(aiGenerationState)")
                
                previewMealPlan = nil
                previewWeeklyGrid = nil
                aiGenerationError = nil
                showingAIPreview = false
                
                print("✅ [MealPlanStore] Preview meal plan applied successfully with all recipes created")
                print("✅ [MealPlanStore] AI generation state set to idle for workflow completion")
                print("🔍 [MealPlanStore] FINAL STATE CHECK: \(aiGenerationState)")
            }
            
        } catch {
            await MainActor.run {
                let errorMessage = "Failed to apply meal plan: \(error.localizedDescription)"
                aiGenerationState = .error(errorMessage)
                aiGenerationError = errorMessage
                
                print("❌ [MealPlanStore] Failed to apply preview meal plan: \(error.localizedDescription)")
            }
        }
    }
    
    /// Save the preview meal plan as a template
    func savePreviewMealPlanAsTemplate(templateName: String, templateDescription: String?) async -> Bool {
        guard let preview = previewMealPlan,
              case .previewing = aiGenerationState else {
            await MainActor.run {
                aiGenerationError = "No preview available to save as template"
            }
            return false
        }
        
        await MainActor.run {
            aiGenerationState = .confirming  // Use same state for template saving
        }
        
        do {
            print("🔄 [MealPlanStore] Saving preview meal plan as template: creating all recipes...")
            
            // CRITICAL: Create all recipes in the backend database before saving template
            let updatedMealPlan = try await createAllRecipesInMealPlan(preview)
            
            // Convert meal plan to template format
            guard let dailyMeals = updatedMealPlan.dailyMeals else {
                throw NSError(domain: "MealPlanStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No daily meals found in meal plan"])
            }
            
            // Convert dailyMeals to template meal format
            var templateMeals: [CreateMealPlanTemplateMeal] = []
            
            for (dayIndex, dailyMeal) in dailyMeals.enumerated() {
                // Process breakfast recipes
                for recipe in dailyMeal.breakfast {
                    let templateMeal = CreateMealPlanTemplateMeal(
                        recipeId: recipe.id,
                        dayOfWeek: dayIndex,
                        mealType: "breakfast",
                        servingSize: 1.0
                    )
                    templateMeals.append(templateMeal)
                }
                
                // Process lunch recipes
                for recipe in dailyMeal.lunch {
                    let templateMeal = CreateMealPlanTemplateMeal(
                        recipeId: recipe.id,
                        dayOfWeek: dayIndex,
                        mealType: "lunch",
                        servingSize: 1.0
                    )
                    templateMeals.append(templateMeal)
                }
                
                // Process dinner recipes
                for recipe in dailyMeal.dinner {
                    let templateMeal = CreateMealPlanTemplateMeal(
                        recipeId: recipe.id,
                        dayOfWeek: dayIndex,
                        mealType: "dinner",
                        servingSize: 1.0
                    )
                    templateMeals.append(templateMeal)
                }
            }
            
            // Create template request
            let templateRequest = CreateMealPlanTemplateRequest(
                name: templateName,
                description: templateDescription,
                meals: templateMeals
            )
            
            // Save template using the template service
            let mealPlanTemplateService = MealPlanTemplateService()
            let _ = try await mealPlanTemplateService.createTemplate(templateRequest)
            
            await MainActor.run {
                // Reset AI generation state after successful save
                resetAIGenerationState()
                print("✅ [MealPlanStore] Successfully saved meal plan as template: '\(templateName)'")
            }
            
            return true
            
        } catch {
            await MainActor.run {
                let errorMessage = "Failed to save as template: \(error.localizedDescription)"
                aiGenerationState = .error(errorMessage)
                aiGenerationError = errorMessage
                
                print("❌ [MealPlanStore] Failed to save preview meal plan as template: \(error.localizedDescription)")
            }
            
            return false
        }
    }
    
    /// Cancel the current preview and return to idle state
    func cancelPreview() {
        resetAIGenerationState()
        print("🔄 [MealPlanStore] AI generation preview cancelled")
    }
    
    /// Reset AI generation state to idle
    func resetAIGenerationState() {
        aiGenerationState = .idle
        previewMealPlan = nil
        previewWeeklyGrid = nil
        aiGenerationError = nil
        showingAIPreview = false
    }
    
    /// Convert MealPlan to WeeklyMealGrid for preview
    private func convertMealPlanToWeeklyGrid(_ mealPlan: MealPlan) -> WeeklyMealGrid {
        var grid = WeeklyMealGrid(weekStartDate: mealPlan.weekStartDate)
        
        print("🔄 [MealPlanStore] Converting meal plan to weekly grid...")
        print("📋 [MealPlanStore] Has dailyMeals: \(mealPlan.dailyMeals != nil)")
        print("📋 [MealPlanStore] Has items: \(mealPlan.items != nil)")
        
        // Handle AI-generated meal plans with dailyMeals
        if let dailyMeals = mealPlan.dailyMeals {
            print("📋 [MealPlanStore] Processing \(dailyMeals.count) daily meals...")
            
            for (dayIndex, dailyMeal) in dailyMeals.enumerated() {
                if dayIndex < grid.dailyMeals.count {
                    print("📋 [MealPlanStore] Day \(dayIndex) (\(dailyMeal.day)): \(dailyMeal.breakfast.count) breakfast, \(dailyMeal.lunch.count) lunch, \(dailyMeal.dinner.count) dinner")
                    
                    // Now dailyMeal contains Recipe objects directly
                    grid.dailyMeals[dayIndex].breakfast = dailyMeal.breakfast
                    grid.dailyMeals[dayIndex].lunch = dailyMeal.lunch
                    grid.dailyMeals[dayIndex].dinner = dailyMeal.dinner
                }
            }
            
            print("✅ [MealPlanStore] Successfully loaded AI meal plan to weekly grid")
            return grid
        }
        
        // Handle regular meal plans with items
        guard let items = mealPlan.items else { return grid }
        
        // Group items by day and meal type
        for item in items {
            let dayIndex = item.dayOfWeek
            if dayIndex < grid.dailyMeals.count, let recipe = item.recipe {
                switch item.mealType.lowercased() {
                case "breakfast":
                    grid.dailyMeals[dayIndex].breakfast.append(recipe)
                case "lunch":
                    grid.dailyMeals[dayIndex].lunch.append(recipe)
                case "dinner":
                    grid.dailyMeals[dayIndex].dinner.append(recipe)
                default:
                    break
                }
            }
        }
        
        return grid
    }
    
    // REMOVED: createRecipeFromMealItem - no longer needed as dailyMeals now contains Recipe objects directly
    
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
        print("🔄 [MealPlanStore] Starting generateCustomMealPlan with description: '\(description)'")
        print("🔄 [MealPlanStore] Parameters - dietType: \(dietType?.rawValue ?? "nil"), allergies: \(allergies), calorieTarget: \(calorieTarget ?? 0)")
        
        await MainActor.run {
            aiGenerationState = .generating
            isGenerating = true
        }
        
        do {
            print("🔄 [MealPlanStore] Calling mealPlanService.generateCustomMealPlan...")
            
            let newMealPlan = try await mealPlanService.generateCustomMealPlan(
                description: description,
                dietType: dietType,
                allergies: allergies,
                dislikes: dislikes,
                calorieTarget: calorieTarget,
                weekStartDate: weekStartDate ?? selectedWeekStartDate,
                additionalRequirements: additionalRequirements
            )
            
            print("✅ [MealPlanStore] Meal plan generated successfully: \(newMealPlan.name)")
            print("📋 [MealPlanStore] Daily meals count: \(newMealPlan.dailyMeals?.count ?? 0)")
            
            // Debug: Print first daily meal if available
            if let dailyMeals = newMealPlan.dailyMeals, !dailyMeals.isEmpty {
                let firstDay = dailyMeals[0]
                print("📋 [MealPlanStore] First day (\(firstDay.day)): \(firstDay.breakfast.count) breakfast, \(firstDay.lunch.count) lunch, \(firstDay.dinner.count) dinner")
                if !firstDay.breakfast.isEmpty {
                    print("📋 [MealPlanStore] First breakfast: \(firstDay.breakfast[0].name)")
                }
            }
            
            // Store as preview instead of immediately applying
            await MainActor.run {
                previewMealPlan = newMealPlan
                print("📋 [MealPlanStore] Setting aiGenerationState to .previewing")
                aiGenerationState = .previewing
                isGenerating = false
            }
            
            return true
        } catch {
            print("❌ [MealPlanStore] Generation failed: \(error.localizedDescription)")
            print("❌ [MealPlanStore] Error details: \(error)")
            
            await MainActor.run {
                isGenerating = false
                aiGenerationState = .error("Failed to generate meal plan: \(error.localizedDescription)")
            }
            
            return false
        }
    }
    
    // MARK: - AI Workflow Management
    
    /// Apply the preview meal plan to the current week
    func applyPreviewMealPlan() async -> Bool {
        guard let preview = previewMealPlan else {
            aiGenerationState = .error("No preview meal plan available")
            return false
        }
        
        aiGenerationState = .confirming
        
        do {
            // Add to meal plans list
            mealPlans.insert(preview, at: 0)
            currentMealPlan = preview
            totalCount += 1
            
            // Update weekly grid if it's for the current week
            if Calendar.current.isDate(preview.weekStartDate, inSameDayAs: selectedWeekStartDate) {
                updateWeeklyGridFromMealPlan(preview)
            }
            
            // Save to backend if needed
            let saveResult = saveLocalMealPlan()
            if case .failure(let error) = saveResult {
                print("⚠️ [MealPlanStore] Failed to save applied meal plan: \(error)")
            }
            
            // Reset AI state
            resetAIGeneration()
            
            return true
        } catch {
            aiGenerationState = .error("Failed to apply meal plan: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Cancel AI generation process
    func cancelAIGeneration() {
        isGenerating = false
        resetAIGeneration()
    }
    
    /// Reset AI generation state
    func resetAIGeneration() {
        aiGenerationState = .idle
        previewMealPlan = nil
        previewWeeklyGrid = nil
        aiGenerationError = nil
        showingAIPreview = false
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
        // First save current week's data with proper error handling
        let saveResult = saveLocalMealPlan()
        if case .failure(let error) = saveResult {
            errorMessage = "Failed to save current week: \(error.localizedDescription)"
        }
        
        let calendar = Calendar.mondayFirst
        let rawNewDate: Date
        
        switch direction {
        case .previous:
            rawNewDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedWeekStartDate) ?? selectedWeekStartDate
        case .next:
            rawNewDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedWeekStartDate) ?? selectedWeekStartDate
        case .current:
            rawNewDate = Date().startOfWeek()
        }
        
        // Normalize the new date to ensure consistency
        let newDate = normalizeWeekStartDate(rawNewDate)
        
        // Check if navigation is within allowed range (current +/- 4 weeks)
        if !isWithinAllowedWeekRange(newDate) {
            errorMessage = "Cannot navigate beyond 4 weeks from current week"
            return
        }
        
        // Update selected week
        selectedWeekStartDate = newDate
        
        // Load meal plan for new week from local storage or create empty
        loadLocalMealPlan()
    }
    
    // MARK: - Week Range Validation
    
    private func isWithinAllowedWeekRange(_ weekStartDate: Date) -> Bool {
        let calendar = Calendar.mondayFirst
        let currentWeekStart = Date().startOfWeek()
        
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
            
            // Check for duplicate recipe in the same day and meal type
            let existingRecipes: [Recipe]
            switch mealType {
            case .breakfast:
                existingRecipes = weeklyGrid.dailyMeals[dayOfWeek].breakfast
            case .lunch:
                existingRecipes = weeklyGrid.dailyMeals[dayOfWeek].lunch
            case .dinner:
                existingRecipes = weeklyGrid.dailyMeals[dayOfWeek].dinner
            }
            
            // Check if recipe already exists in this meal slot
            if existingRecipes.contains(where: { $0.id == recipe.id }) {
                errorMessage = "This recipe is already added to \(mealType.rawValue) for this day"
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
        }
        
        // Save to local storage immediately (critical for data persistence)
        let saveResult = saveLocalMealPlan()
        if case .failure(let error) = saveResult {
            errorMessage = "Failed to save meal plan: \(error.localizedDescription)"
        }
        
        // Add to recent meals
        await addToRecentMeals(recipe)
    }
    
    func removeMealFromWeek(recipe: Recipe, dayOfWeek: Int, mealType: MealType) async {
        await MainActor.run {
            guard dayOfWeek < weeklyGrid.dailyMeals.count else {
                errorMessage = "Invalid day of week: \(dayOfWeek)"
                return
            }
            
            // Remove recipe from appropriate meal type
            switch mealType {
            case .breakfast:
                weeklyGrid.dailyMeals[dayOfWeek].breakfast.removeAll { $0.id == recipe.id }
            case .lunch:
                weeklyGrid.dailyMeals[dayOfWeek].lunch.removeAll { $0.id == recipe.id }
            case .dinner:
                weeklyGrid.dailyMeals[dayOfWeek].dinner.removeAll { $0.id == recipe.id }
            }
        }
        
        // Save to local storage immediately
        let saveResult = saveLocalMealPlan()
        if case .failure(let error) = saveResult {
            errorMessage = "Failed to save meal plan: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Save/Update Weekly Grid to Backend
    
    /// Save current weekly grid to backend meal plan (triggered by Save/Update button)
    func saveWeeklyGridToBackend() async -> Bool {
        guard let mealPlan = activeMealPlan else {
            errorMessage = "No active meal plan to save"
            return false
        }
        
        isLoading = true
        
        do {
            let updatedPlan = try await mealPlanService.syncWeeklyGridToBackend(
                mealPlanId: mealPlan.id, 
                weeklyGrid: weeklyGrid
            )
            
            await MainActor.run {
                activeMealPlan = updatedPlan
                print("✅ [MealPlanStore] Successfully saved weekly grid to backend")
            }
            
            isLoading = false
            return true
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save meal plan: \(error.localizedDescription)"
                print("⚠️ [MealPlanStore] Failed to save weekly grid to backend: \(error.localizedDescription)")
            }
            
            isLoading = false
            return false
        }
    }
    
    // MARK: - Create Meal Plan for Current Week
    
    private func createMealPlanForCurrentWeek() async {
        let calendar = Calendar.mondayFirst
        let now = Date()
        let weekStart = now.startOfWeek()
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
            instructions: ["Custom meal added manually"],
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
    
    // MARK: - Data Management
    
    /// Clear all data when user logs out
    func clearAllData() {
        mealPlans = []
        currentMealPlan = nil
        activeMealPlan = nil
        weeklyGrid = WeeklyMealGrid(weekStartDate: selectedWeekStartDate)
        shoppingList = []
        nutritionAnalysis = nil
        recentMeals = []
        aiRecommendedRecipes = []
        currentPage = 1
        totalPages = 1
        hasMorePages = false
        totalCount = 0
        errorMessage = nil
        
        // Clear AI generation state
        resetAIGenerationState()
        
        // Clear local storage
        LocalMealPlanStorage.shared.clearAllMealPlans()
        
        print("🗑️ [MealPlanStore] Cleared all data")
    }
    
    /// Remove a deleted recipe from all meal plans and weekly grid
    func removeDeletedRecipe(recipeId: String) {
        // Remove from weekly grid
        for i in 0..<weeklyGrid.dailyMeals.count {
            weeklyGrid.dailyMeals[i].breakfast.removeAll { $0.id == recipeId }
            weeklyGrid.dailyMeals[i].lunch.removeAll { $0.id == recipeId }
            weeklyGrid.dailyMeals[i].dinner.removeAll { $0.id == recipeId }
        }
        
        // Remove from recent meals
        recentMeals.removeAll { $0.id == recipeId }
        
        // Remove from AI recommendations
        aiRecommendedRecipes.removeAll { $0.id == recipeId }
        
        // Save updated weekly grid
        let _ = saveLocalMealPlan()
        
        print("🗑️ [MealPlanStore] Removed deleted recipe \(recipeId) from meal plans")
    }
    
    /// Clear all meals for the current week
    private func clearAllMealsForWeek() async {
        await MainActor.run {
            for i in 0..<weeklyGrid.dailyMeals.count {
                weeklyGrid.dailyMeals[i].breakfast = []
                weeklyGrid.dailyMeals[i].lunch = []
                weeklyGrid.dailyMeals[i].dinner = []
            }
        }
        
        // Save cleared state
        let _ = saveLocalMealPlan()
    }
    
    /// Find empty meal slots in the current week
    private func findEmptyMealSlots() -> [(dayIndex: Int, mealType: MealType)] {
        var emptySlots: [(dayIndex: Int, mealType: MealType)] = []
        
        for (dayIndex, dailyMeal) in weeklyGrid.dailyMeals.enumerated() {
            if dailyMeal.breakfast.isEmpty {
                emptySlots.append((dayIndex, .breakfast))
            }
            if dailyMeal.lunch.isEmpty {
                emptySlots.append((dayIndex, .lunch))
            }
            if dailyMeal.dinner.isEmpty {
                emptySlots.append((dayIndex, .dinner))
            }
        }
        
        return emptySlots
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
            
            // Generate AI recommendations for each empty slot
            for slot in emptySlots {
                // TODO: Replace with actual AI service call
                let recommendations = [Recipe.sampleRecipe]
                
                if let recipe = recommendations.first {
                    let _ = try await mealPlanService.addMealPlanItem(
                        mealPlanId: mealPlan.id,
                        recipeId: recipe.id,
                        dayOfWeek: slot.dayIndex,
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
    
    // MARK: - Recipe Creation Logic
    
    /// Create all recipes from a MealPlan's dailyMeals in the backend database
    /// This is called during Apply and Save As Template operations
    private func createAllRecipesInMealPlan(_ mealPlan: MealPlan) async throws -> MealPlan {
        guard let dailyMeals = mealPlan.dailyMeals else {
            print("⚠️ [MealPlanStore] No dailyMeals found in meal plan, returning original")
            return mealPlan
        }
        
        print("🔄 [MealPlanStore] Creating all recipes for meal plan: \(mealPlan.name)")
        print("📋 [MealPlanStore] Processing \(dailyMeals.count) daily meals...")
        
        let recipeService = RecipeService()
        var updatedDailyMeals: [DailyMeal] = []
        var recipesCreated = 0
        var recipesSkipped = 0
        
        for (dayIndex, dailyMeal) in dailyMeals.enumerated() {
            print("📅 [MealPlanStore] Processing day \(dayIndex + 1): \(dailyMeal.day)")
            
            // Process each meal type
            let updatedBreakfast = try await createRecipesIfNeeded(dailyMeal.breakfast, recipeService: recipeService, mealType: "breakfast", dayName: dailyMeal.day, recipesCreated: &recipesCreated, recipesSkipped: &recipesSkipped)
            let updatedLunch = try await createRecipesIfNeeded(dailyMeal.lunch, recipeService: recipeService, mealType: "lunch", dayName: dailyMeal.day, recipesCreated: &recipesCreated, recipesSkipped: &recipesSkipped)
            let updatedDinner = try await createRecipesIfNeeded(dailyMeal.dinner, recipeService: recipeService, mealType: "dinner", dayName: dailyMeal.day, recipesCreated: &recipesCreated, recipesSkipped: &recipesSkipped)
            
            let updatedDailyMeal = DailyMeal(
                day: dailyMeal.day,
                breakfast: updatedBreakfast,
                lunch: updatedLunch,
                dinner: updatedDinner
            )
            updatedDailyMeals.append(updatedDailyMeal)
        }
        
        print("✅ [MealPlanStore] Recipe creation completed:")
        print("   📦 Recipes created: \(recipesCreated)")
        print("   ⏩ Recipes skipped (already exist): \(recipesSkipped)")
        
        // Create updated meal plan with the new recipe data
        let updatedMealPlan = MealPlan(
            id: mealPlan.id,
            userId: mealPlan.userId,
            name: mealPlan.name,
            description: mealPlan.description,
            weekStartDate: mealPlan.weekStartDate,
            isActive: mealPlan.isActive,
            planDescription: mealPlan.planDescription,
            analysisText: mealPlan.analysisText,
            items: mealPlan.items,
            itemsCount: mealPlan.itemsCount,
            dailyMeals: updatedDailyMeals,  // Use updated dailyMeals
            createdAt: mealPlan.createdAt,
            updatedAt: mealPlan.updatedAt
        )
        
        return updatedMealPlan
    }
    
    /// Create recipes if they don't already exist in the backend
    private func createRecipesIfNeeded(_ recipes: [Recipe], recipeService: RecipeService, mealType: String, dayName: String, recipesCreated: inout Int, recipesSkipped: inout Int) async throws -> [Recipe] {
        var updatedRecipes: [Recipe] = []
        
        for recipe in recipes {
            print("🍽️ [MealPlanStore] Processing \(mealType) recipe: '\(recipe.name)' (ID: \(recipe.id))")
            
            do {
                // First, try to fetch the recipe from backend to see if it exists
                let existingRecipe = try await recipeService.getRecipe(id: recipe.id)
                print("✅ [MealPlanStore] Recipe '\(recipe.name)' already exists in backend")
                updatedRecipes.append(existingRecipe)
                recipesSkipped += 1
                
            } catch {
                print("🔧 [MealPlanStore] Recipe '\(recipe.name)' not found in backend, creating it...")
                
                do {
                    // Convert Recipe to AI format for backend creation
                    let aiIngredients = recipe.ingredients.map { ingredient in
                        AIIngredient(
                            name: ingredient.name,
                            amount: "\(ingredient.amount) \(ingredient.unit)".trimmingCharacters(in: .whitespaces)
                        )
                    }
                    
                    let aiNutritionInfo = AINutritionInfo(
                        calories: extractNumericValue(from: recipe.nutritionInfo?.calories),
                        protein: extractNumericValue(from: recipe.nutritionInfo?.protein),
                        carbohydrates: extractNumericValue(from: recipe.nutritionInfo?.carbohydrates),
                        fat: extractNumericValue(from: recipe.nutritionInfo?.fat),
                        fiber: extractNumericValue(from: recipe.nutritionInfo?.fiber),
                        sodium: extractNumericValue(from: recipe.nutritionInfo?.sodium),
                        sugar: extractNumericValue(from: recipe.nutritionInfo?.sugar),
                        servings: recipe.nutritionInfo?.servings
                    )
                    
                    let aiRecipeData = AIGeneratedRecipe(
                        name: recipe.name,
                        description: recipe.description ?? "",
                        cuisine: recipe.cuisine ?? "Unknown",
                        difficulty: recipe.difficulty ?? .medium,
                        prepTime: recipe.prepTime ?? 30,
                        cookTime: recipe.cookTime ?? 30,
                        imageUrl: recipe.imageUrl,
                        ingredients: aiIngredients,
                        instructions: recipe.instructions,
                        nutritionInfo: aiNutritionInfo,
                        tags: recipe.tags
                    )
                    
                    let createRequest = CreateRecipeFromAIRequest(
                        aiRecipeData: aiRecipeData,
                        saveToAccount: true,
                        addToMealPlan: nil,
                        mealPlanDay: nil,
                        mealPlanType: nil
                    )
                    
                    let createdRecipe = try await recipeService.createRecipeFromAI(createRequest)
                    print("✅ [MealPlanStore] Successfully created recipe '\(createdRecipe.name)' in backend with ID: \(createdRecipe.id)")
                    updatedRecipes.append(createdRecipe)
                    recipesCreated += 1
                    
                } catch {
                    print("❌ [MealPlanStore] Failed to create recipe '\(recipe.name)' in backend: \(error)")
                    // Still add the original recipe to continue processing, but log the error
                    updatedRecipes.append(recipe)
                    throw error
                }
            }
        }
        
        return updatedRecipes
    }
    
    /// Extract numeric value from nutrition string (e.g., "25g" -> 25)
    private func extractNumericValue(from nutritionString: String?) -> Int? {
        guard let str = nutritionString, !str.isEmpty else { return nil }
        
        // Use regex to extract the first number from the string
        let pattern = #"(\d+(?:\.\d+)?)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)),
           let range = Range(match.range(at: 1), in: str) {
            let numberString = String(str[range])
            return Int(Double(numberString) ?? 0)
        }
        
        return nil
    }
    
    // MARK: - AI Generation State Computed Properties
    
    var isAIGenerating: Bool {
        if case .generating = aiGenerationState {
            return true
        }
        return false
    }
    
    var isAIPreviewing: Bool {
        if case .previewing = aiGenerationState {
            return true
        }
        return false
    }
    
    var isAIConfirming: Bool {
        if case .confirming = aiGenerationState {
            return true
        }
        return false
    }
    
    var hasAIError: Bool {
        if case .error = aiGenerationState {
            return true
        }
        return false
    }
    
    var canConfirmPreview: Bool {
        if case .previewing = aiGenerationState {
            return previewMealPlan != nil && previewWeeklyGrid != nil
        }
        return false
    }
    
    var aiGenerationStateDescription: String {
        switch aiGenerationState {
        case .idle:
            return "Ready to generate"
        case .generating:
            return "Generating meal plan..."
        case .previewing:
            return "Preview ready"
        case .confirming:
            return "Applying meal plan..."
        case .error(let message):
            return "Error: \(message)"
        }
    }

    
    /// Cleanup method for deinit
    deinit {
        // Remove observers to prevent memory leaks
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
    }
    
    func clearAIGenerationError() {
        aiGenerationError = nil
        if case .error = aiGenerationState {
            aiGenerationState = .idle
        }
    }
    
    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}

// MARK: - Supporting Types

struct MealSlot {
    let dayOfWeek: Int
    let mealType: MealType
}

// MARK: - Supporting Enums
// WeekDirection is now defined in SharedEnums.swift

// MARK: - Extensions

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}
