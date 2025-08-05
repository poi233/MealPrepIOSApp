//
//  AIGenerationService.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 8/3/25.
//  Extracted from MealPlanStore.swift for better separation of concerns.
//

import SwiftUI
import Combine

// MARK: - AI Generation State
enum AIGenerationState: Equatable {
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

// MARK: - AI Generation Service
@MainActor
class AIGenerationService: ObservableObject {
    @Published var aiGenerationState: AIGenerationState = .idle
    @Published var previewMealPlan: MealPlan?
    @Published var previewWeeklyGrid: WeeklyMealGrid?
    @Published var aiGenerationError: String?
    @Published var showingAIPreview = false
    @Published var isGenerating = false
    
    private let aiService = AIService()
    private let recipeService = RecipeService()
    
    // MARK: - Batch Recipe Generation State
    @Published var batchGenerationProgress: BatchGenerationProgress?
    @Published var isBatchGenerating = false
    
    // MARK: - AI Generation Methods
    
    func generateAIMealPlan(request: AIGenerationRequest) async {
        guard aiGenerationState == .idle else {
            print("⚠️ [AIGenerationService] Cannot start AI generation: already in progress")
            return
        }
        
        aiGenerationState = .generating
        isGenerating = true
        aiGenerationError = nil
        
        do {
            print("🤖 [AIGenerationService] Starting AI meal plan generation...")
            print("🔍 [AIGenerationService] Request description: '\(request.description)'")
            print("🔍 [AIGenerationService] Diet type: \(request.dietType?.rawValue ?? "none")")
            print("🔍 [AIGenerationService] Allergies: \(request.allergies)")
            print("🔍 [AIGenerationService] Calorie target: \(request.calorieTarget ?? 0)")
            
            // Convert AIGenerationRequest to GenerateMealPlanRequest
            var dietaryPreferences: [String: String] = [:]
            if let dietType = request.dietType {
                dietaryPreferences["dietType"] = dietType.rawValue
            }
            
            // No date validation needed - weekStartDate will not be sent to backend
            
            let apiRequest = GenerateMealPlanRequest(
                planDescription: request.description,
                dietaryPreferences: dietaryPreferences.isEmpty ? nil : dietaryPreferences,
                allergies: request.allergies.isEmpty ? nil : request.allergies,
                dislikes: request.dislikes.isEmpty ? nil : request.dislikes,
                calorieTarget: request.calorieTarget,
                additionalRequirements: request.additionalRequirements
            )
            
            // DETAILED DEBUG LOGGING
            print("🔍 [AIGenerationService] API Request Detailed Debug:")
            print("🔍 [AIGenerationService] planDescription: '\(apiRequest.planDescription)'")
            print("🔍 [AIGenerationService] dietaryPreferences: \(apiRequest.dietaryPreferences?.description ?? "nil")")
            print("🔍 [AIGenerationService] allergies: \(apiRequest.allergies?.description ?? "nil")")
            print("🔍 [AIGenerationService] dislikes: \(apiRequest.dislikes?.description ?? "nil")")
            print("🔍 [AIGenerationService] calorieTarget: \(apiRequest.calorieTarget?.description ?? "nil")")
            print("🔍 [AIGenerationService] additionalRequirements: '\(apiRequest.additionalRequirements ?? "nil")'")
            print("🔍 [AIGenerationService] weekStartDate: NOT SENT (Phase 1 cleanup)")
            
            // Check for empty or invalid values that might cause validation errors
            if apiRequest.planDescription.isEmpty {
                print("❌ [AIGenerationService] planDescription is empty!")
            }
            if apiRequest.planDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("❌ [AIGenerationService] planDescription is only whitespace!")
            }
            
            print("🌐 [AIGenerationService] Making API call to generate meal plan...")
            
            // Call the real AI service
            let generatedMealPlan = try await aiService.generateMealPlan(apiRequest)
            
            print("✅ [AIGenerationService] API call successful! Generated meal plan: '\(generatedMealPlan.name)'")
            print("🔍 [AIGenerationService] Plan has \(generatedMealPlan.items?.count ?? 0) items")
            
            await handleSuccessfulGeneration(generatedMealPlan)
            
        } catch {
            print("❌ [AIGenerationService] API call failed: \(error)")
            await handleGenerationError(error)
        }
    }
    
    private func handleSuccessfulGeneration(_ mealPlan: MealPlan) async {
        print("✅ [AIGenerationService] AI generation completed successfully")
        print("🔍 [AIGenerationService] Generated MealPlan detailed debug:")
        print("🔍 [AIGenerationService] - Plan name: '\(mealPlan.name)'")
        print("🔍 [AIGenerationService] - Plan description: '\(mealPlan.description ?? "nil")'")
        print("🔍 [AIGenerationService] - Plan planDescription: '\(mealPlan.planDescription ?? "nil")'")
        print("🔍 [AIGenerationService] - Has dailyMeals: \(mealPlan.dailyMeals != nil)")
        print("🔍 [AIGenerationService] - Has items: \(mealPlan.items != nil)")
        print("🔍 [AIGenerationService] - Has lightweightDailyMeals: \(mealPlan.lightweightDailyMeals != nil)")
        
        if let dailyMeals = mealPlan.dailyMeals {
            print("🔍 [AIGenerationService] - DailyMeals count: \(dailyMeals.count)")
            for (index, dailyMeal) in dailyMeals.enumerated() {
                print("🔍 [AIGenerationService] - Day \(index) (\(dailyMeal.day)): \(dailyMeal.breakfast.count) breakfast, \(dailyMeal.lunch.count) lunch, \(dailyMeal.dinner.count) dinner")
                
                // Log a few recipe names for debugging
                if !dailyMeal.breakfast.isEmpty {
                    print("🔍 [AIGenerationService]   - Breakfast: \(dailyMeal.breakfast.map { $0.name }.joined(separator: ", "))")
                }
                if !dailyMeal.lunch.isEmpty {
                    print("🔍 [AIGenerationService]   - Lunch: \(dailyMeal.lunch.map { $0.name }.joined(separator: ", "))")
                }
                if !dailyMeal.dinner.isEmpty {
                    print("🔍 [AIGenerationService]   - Dinner: \(dailyMeal.dinner.map { $0.name }.joined(separator: ", "))")
                }
            }
        }
        
        if let items = mealPlan.items {
            print("🔍 [AIGenerationService] - Items count: \(items.count)")
            for item in items.prefix(3) {
                print("🔍 [AIGenerationService]   - Item: day \(item.dayOfWeek), \(item.mealType), recipe: \(item.recipe?.name ?? "nil")")
            }
        }
        
        if let lightweightDailyMeals = mealPlan.lightweightDailyMeals {
            print("🔍 [AIGenerationService] - LightweightDailyMeals count: \(lightweightDailyMeals.count)")
            for (index, lightweightDailyMeal) in lightweightDailyMeals.enumerated() {
                print("🔍 [AIGenerationService] - Day \(index) (\(lightweightDailyMeal.day)): \(lightweightDailyMeal.breakfast.count) breakfast, \(lightweightDailyMeal.lunch.count) lunch, \(lightweightDailyMeal.dinner.count) dinner")
                
                // Log a few recipe names for debugging
                if !lightweightDailyMeal.breakfast.isEmpty {
                    print("🔍 [AIGenerationService]   - Breakfast: \(lightweightDailyMeal.breakfast.map { $0.name }.joined(separator: ", "))")
                }
                if !lightweightDailyMeal.lunch.isEmpty {
                    print("🔍 [AIGenerationService]   - Lunch: \(lightweightDailyMeal.lunch.map { $0.name }.joined(separator: ", "))")
                }
                if !lightweightDailyMeal.dinner.isEmpty {
                    print("🔍 [AIGenerationService]   - Dinner: \(lightweightDailyMeal.dinner.map { $0.name }.joined(separator: ", "))")
                }
            }
        }
        
        // Convert to preview format
        let weeklyGrid = convertMealPlanToWeeklyGrid(mealPlan)
        
        print("🔍 [AIGenerationService] Weekly grid conversion result:")
        print("🔍 [AIGenerationService] - Grid has \(weeklyGrid.dailyMeals.count) days")
        for (index, day) in weeklyGrid.dailyMeals.enumerated() {
            print("🔍 [AIGenerationService] - Day \(index) (\(day.day)): \(day.breakfast.count) breakfast, \(day.lunch.count) lunch, \(day.dinner.count) dinner")
        }
        
        previewWeeklyGrid = weeklyGrid
        previewMealPlan = mealPlan
        aiGenerationState = .previewing
        showingAIPreview = true
        isGenerating = false
        
        print("✅ [AIGenerationService] Preview data set successfully")
        print("🔍 [AIGenerationService] - previewMealPlan is set: \(self.previewMealPlan != nil)")
        print("🔍 [AIGenerationService] - previewWeeklyGrid is set: \(self.previewWeeklyGrid != nil)")
        print("🔍 [AIGenerationService] - aiGenerationState: \(self.aiGenerationState)")
    }
    
    private func handleGenerationError(_ error: Error) async {
        print("❌ [AIGenerationService] AI generation failed: \\(error.localizedDescription)")
        
        aiGenerationError = error.localizedDescription
        aiGenerationState = .error(error.localizedDescription)
        isGenerating = false
    }
    
    private func convertMealPlanToWeeklyGrid(_ mealPlan: MealPlan) -> WeeklyMealGrid {
        var grid = WeeklyMealGrid()
        
        print("🔄 [AIGenerationService] Converting MealPlan to WeeklyGrid...")
        print("🔍 [AIGenerationService] MealPlan has dailyMeals: \(mealPlan.dailyMeals != nil)")
        print("🔍 [AIGenerationService] MealPlan has items: \(mealPlan.items != nil)")
        print("🔍 [AIGenerationService] MealPlan has lightweightDailyMeals: \(mealPlan.lightweightDailyMeals != nil)")
        
        // PRIORITY 1: Handle AI-generated meal plans with dailyMeals structure (full Recipe objects)
        if let dailyMeals = mealPlan.dailyMeals {
            print("🔍 [AIGenerationService] Processing \(dailyMeals.count) daily meals from AI response")
            
            for (dayIndex, dailyMeal) in dailyMeals.enumerated() {
                if dayIndex < grid.dailyMeals.count {
                    print("🔍 [AIGenerationService] Day \(dayIndex) (\(dailyMeal.day)): \(dailyMeal.breakfast.count) breakfast, \(dailyMeal.lunch.count) lunch, \(dailyMeal.dinner.count) dinner")
                    
                    // Direct assignment - dailyMeal already contains Recipe objects
                    grid.dailyMeals[dayIndex].breakfast = dailyMeal.breakfast
                    grid.dailyMeals[dayIndex].lunch = dailyMeal.lunch
                    grid.dailyMeals[dayIndex].dinner = dailyMeal.dinner
                }
            }
            
            print("✅ [AIGenerationService] Successfully converted dailyMeals to WeeklyGrid")
            return grid
        }
        
        // PRIORITY 2: Handle AI-generated meal plans with lightweightDailyMeals structure (RecipeStub objects)
        if let lightweightDailyMeals = mealPlan.lightweightDailyMeals {
            print("🔍 [AIGenerationService] Processing \(lightweightDailyMeals.count) lightweight daily meals from AI response")
            
            for (dayIndex, lightweightDailyMeal) in lightweightDailyMeals.enumerated() {
                if dayIndex < grid.dailyMeals.count {
                    print("🔍 [AIGenerationService] Day \(dayIndex) (\(lightweightDailyMeal.day)): \(lightweightDailyMeal.breakfast.count) breakfast, \(lightweightDailyMeal.lunch.count) lunch, \(lightweightDailyMeal.dinner.count) dinner")
                    
                    // Convert RecipeStub objects to Recipe objects for WeeklyGrid compatibility
                    let breakfastRecipes = lightweightDailyMeal.breakfast.map { $0.toRecipe() }
                    let lunchRecipes = lightweightDailyMeal.lunch.map { $0.toRecipe() }
                    let dinnerRecipes = lightweightDailyMeal.dinner.map { $0.toRecipe() }
                    
                    // Log converted recipes for debugging
                    if !breakfastRecipes.isEmpty {
                        print("🔍 [AIGenerationService]   - Breakfast converted: \(breakfastRecipes.map { $0.name }.joined(separator: ", "))")
                    }
                    if !lunchRecipes.isEmpty {
                        print("🔍 [AIGenerationService]   - Lunch converted: \(lunchRecipes.map { $0.name }.joined(separator: ", "))")
                    }
                    if !dinnerRecipes.isEmpty {
                        print("🔍 [AIGenerationService]   - Dinner converted: \(dinnerRecipes.map { $0.name }.joined(separator: ", "))")
                    }
                    
                    // Assign converted recipes to grid
                    grid.dailyMeals[dayIndex].breakfast = breakfastRecipes
                    grid.dailyMeals[dayIndex].lunch = lunchRecipes
                    grid.dailyMeals[dayIndex].dinner = dinnerRecipes
                }
            }
            
            print("✅ [AIGenerationService] Successfully converted lightweightDailyMeals to WeeklyGrid")
            return grid
        }
        
        // PRIORITY 3: Handle traditional meal plan items structure (legacy format)
        if let items = mealPlan.items {
            print("🔍 [AIGenerationService] Processing \(items.count) meal plan items from legacy structure")
            
            // Group meal plan items by day of week
            let groupedItems = Dictionary(grouping: items) { $0.dayOfWeek }
            
            for dayIndex in 0..<7 {
                if dayIndex < grid.dailyMeals.count,
                   let dayItems = groupedItems[dayIndex] {
                    
                    // Group by meal type
                    let breakfastItems = dayItems.filter { $0.mealType == "breakfast" }.compactMap { $0.recipe }
                    let lunchItems = dayItems.filter { $0.mealType == "lunch" }.compactMap { $0.recipe }
                    let dinnerItems = dayItems.filter { $0.mealType == "dinner" }.compactMap { $0.recipe }
                    
                    // Update the daily meals
                    grid.dailyMeals[dayIndex].breakfast = breakfastItems
                    grid.dailyMeals[dayIndex].lunch = lunchItems
                    grid.dailyMeals[dayIndex].dinner = dinnerItems
                }
            }
            
            print("✅ [AIGenerationService] Successfully converted items to WeeklyGrid")
            return grid
        }
        
        // No data available
        print("⚠️ [AIGenerationService] No dailyMeals, lightweightDailyMeals, or items found in MealPlan - returning empty grid")
        return grid
    }
    
    // MARK: - Preview Management
    
    func confirmAIGeneration() async -> WeeklyMealGrid? {
        guard aiGenerationState == .previewing,
              let previewGrid = previewWeeklyGrid else {
            print("⚠️ [AIGenerationService] Cannot confirm: no preview available")
            return nil
        }
        
        aiGenerationState = .confirming
        
        // Simulate brief confirmation delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Reset state
        resetAIGenerationState()
        
        return previewGrid
    }
    
    func cancelAIGeneration() {
        print("🚫 [AIGenerationService] AI generation cancelled by user")
        resetAIGenerationState()
    }
    
    func resetAIGenerationState() {
        aiGenerationState = .idle
        previewMealPlan = nil
        previewWeeklyGrid = nil
        aiGenerationError = nil
        showingAIPreview = false
        isGenerating = false
    }
    
    // MARK: - Computed Properties
    
    var canStartGeneration: Bool {
        aiGenerationState == .idle
    }
    
    var canPreview: Bool {
        aiGenerationState.canPreview
    }
    
    var canConfirm: Bool {
        aiGenerationState.canConfirm
    }
    
    var isInGenerationFlow: Bool {
        switch aiGenerationState {
        case .idle:
            return false
        default:
            return true
        }
    }
    
    // MARK: - Batch Recipe Generation from RecipeStubs
    
    /// Batch convert RecipeStubs to full Recipes using create-recipe-from-ai API
    func batchCreateRecipesFromStubs(_ recipeStubs: [RecipeStub]) async throws -> [Recipe] {
        print("🔄 [AIGenerationService] Starting batch recipe generation for \(recipeStubs.count) stubs")
        
        isBatchGenerating = true
        batchGenerationProgress = BatchGenerationProgress(
            total: recipeStubs.count,
            completed: 0,
            failed: 0,
            currentRecipe: nil
        )
        
        var generatedRecipes: [Recipe] = []
        var failedStubs: [RecipeStub] = []
        
        // Use TaskGroup for concurrent processing with limited concurrency
        try await withThrowingTaskGroup(of: RecipeGenerationResult.self) { group in
            let concurrencyLimit = min(3, recipeStubs.count) // Limit to 3 concurrent requests
            var activeCount = 0
            var stubIndex = 0
            
            // Start initial batch of tasks
            while activeCount < concurrencyLimit && stubIndex < recipeStubs.count {
                let stub = recipeStubs[stubIndex]
                group.addTask { [weak self] in
                    await self?.generateSingleRecipeFromStub(stub, index: stubIndex) ?? RecipeGenerationResult(recipe: nil, stub: stub, index: stubIndex, error: "Service unavailable")
                }
                activeCount += 1
                stubIndex += 1
            }
            
            // Process results and add new tasks
            for try await result in group {
                await handleBatchGenerationResult(result)
                
                if let recipe = result.recipe {
                    generatedRecipes.append(recipe)
                } else {
                    failedStubs.append(result.stub)
                }
                
                // Add next task if available
                if stubIndex < recipeStubs.count {
                    let stub = recipeStubs[stubIndex]
                    group.addTask { [weak self] in
                        await self?.generateSingleRecipeFromStub(stub, index: stubIndex) ?? RecipeGenerationResult(recipe: nil, stub: stub, index: stubIndex, error: "Service unavailable")
                    }
                    stubIndex += 1
                }
                
                activeCount -= 1
            }
        }
        
        // Handle failed stubs with fallback to basic Recipe objects
        for failedStub in failedStubs {
            print("⚠️ [AIGenerationService] Using fallback recipe for failed stub: \(failedStub.name)")
            generatedRecipes.append(failedStub.toRecipe())
        }
        
        print("✅ [AIGenerationService] Batch generation completed: \(generatedRecipes.count - failedStubs.count) successful, \(failedStubs.count) fallbacks")
        
        isBatchGenerating = false
        batchGenerationProgress = nil
        
        return generatedRecipes
    }
    
    /// Generate a single Recipe from RecipeStub using create-recipe-from-ai API
    private func generateSingleRecipeFromStub(_ stub: RecipeStub, index: Int) async -> RecipeGenerationResult {
        do {
            print("🤖 [AIGenerationService] Generating recipe \(index + 1): \(stub.name)")
            
            await updateBatchProgress(currentRecipe: stub.name)
            
            // Convert RecipeStub to AIGeneratedRecipe
            let aiRecipe = stub.toAIGeneratedRecipe()
            
            // Create API request
            let request = CreateRecipeFromAIRequest(
                aiRecipeData: aiRecipe,
                saveToAccount: true,
                addToMealPlan: nil,
                mealPlanDay: nil,
                mealPlanType: nil
            )
            
            // Call create-recipe-from-ai API
            let generatedRecipe = try await recipeService.createRecipeFromAI(request)
            
            print("✅ [AIGenerationService] Successfully generated recipe: \(generatedRecipe.name)")
            
            return RecipeGenerationResult(recipe: generatedRecipe, stub: stub, index: index, error: nil)
            
        } catch {
            print("❌ [AIGenerationService] Failed to generate recipe for \(stub.name): \(error)")
            return RecipeGenerationResult(recipe: nil, stub: stub, index: index, error: error.localizedDescription)
        }
    }
    
    /// Handle individual batch generation result
    @MainActor
    private func handleBatchGenerationResult(_ result: RecipeGenerationResult) {
        guard var progress = batchGenerationProgress else { return }
        
        if result.recipe != nil {
            progress.completed += 1
        } else {
            progress.failed += 1
        }
        
        print("📊 [AIGenerationService] Progress: \(progress.completed + progress.failed)/\(progress.total) (\(progress.completed) successful, \(progress.failed) failed)")
        
        batchGenerationProgress = progress
    }
    
    /// Update batch generation progress
    @MainActor
    private func updateBatchProgress(currentRecipe: String) {
        batchGenerationProgress?.currentRecipe = currentRecipe
    }
}

// MARK: - Supporting Models for Batch Generation

/// Progress tracking for batch recipe generation
struct BatchGenerationProgress {
    let total: Int
    var completed: Int
    var failed: Int
    var currentRecipe: String?
    
    var successRate: Double {
        guard total > 0 else { return 0.0 }
        return Double(completed) / Double(total)
    }
    
    var completionRate: Double {
        guard total > 0 else { return 0.0 }
        return Double(completed + failed) / Double(total)
    }
    
    var isComplete: Bool {
        return (completed + failed) == total
    }
}

/// Result of individual recipe generation
struct RecipeGenerationResult {
    let recipe: Recipe?
    let stub: RecipeStub
    let index: Int
    let error: String?
    
    var isSuccess: Bool {
        return recipe != nil
    }
}

// MARK: - Supporting Extensions
// Note: RecipeStub extension removed as we now work directly with MealPlan/Recipe types