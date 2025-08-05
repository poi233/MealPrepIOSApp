//
//  AIGenerationManager.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 8/3/25.
//

import Foundation
import SwiftUI
import Combine

/**
 * Unified AI Generation Manager - Single Source of Truth
 * 
 * Consolidates state management from AIGenerationService and AIWorkflowCoordinator
 * into a single, coherent system. Maintains the validated two-phase design
 * (RecipeStub → Recipe) while eliminating architectural duplication.
 * 
 * Key Improvements:
 * - Single source of truth for all AI generation state
 * - Unified error handling with AIWorkflowError
 * - Consolidated conversion logic
 * - Clear separation of concerns
 * - Proper async/await patterns
 */
@MainActor
class AIGenerationManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published var state: AIGenerationState = .idle
    @Published var workflowStep: AIWorkflowStep = .input
    @Published var error: AIWorkflowError?
    @Published var isLoading = false
    
    // MARK: - Preview Data (Single Source of Truth)
    
    @Published var previewMealPlan: MealPlan?
    @Published var previewWeeklyGrid: WeeklyMealGrid?
    @Published var currentRequest: AIGenerationRequest?
    
    // MARK: - Dependencies
    
    private let mealPlanService: MealPlanService
    private let recipeService: RecipeService
    private var generationTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(mealPlanService: MealPlanService, recipeService: RecipeService) {
        self.mealPlanService = mealPlanService
        self.recipeService = recipeService
    }
    
    // MARK: - Public API
    
    /// Start AI meal plan generation with the two-phase workflow
    func generateMealPlan(_ request: AIGenerationRequest) async {
        print("🚀 [AIGenerationManager] Starting meal plan generation")
        
        currentRequest = request
        state = .generating
        workflowStep = .generating
        isLoading = true
        error = nil
        
        // Cancel any existing generation
        generationTask?.cancel()
        
        generationTask = Task {
            await executeGeneration(request)
        }
    }
    
    /// Confirm and apply the previewed meal plan
    func confirmPreview() async {
        guard let mealPlan = previewMealPlan else {
            await handleError(.previewUnavailable)
            return
        }
        
        print("✅ [AIGenerationManager] Confirming preview meal plan")
        
        state = .confirming
        workflowStep = .confirming
        isLoading = true
        error = nil
        
        do {
            // Apply the meal plan by creating it in the backend if needed
            // For AI-generated meal plans, they might already be saved or need to be created
            if isPreviewMealPlan(mealPlan) {
                // This is a preview meal plan, we need to create it as a proper meal plan
                let createRequest = CreateMealPlanRequest(
                    name: mealPlan.name,
                    description: mealPlan.description,
                    startDate: Date().startOfWeek(),
                    endDate: Calendar.current.date(byAdding: .day, value: 6, to: Date().startOfWeek()) ?? Date().startOfWeek(),
                    items: nil, // Will be populated from dailyMeals
                    preferences: nil
                )
                
                let confirmedPlan = try await mealPlanService.createMealPlan(createRequest)
                await completeWorkflowWithPlan(confirmedPlan)
            } else {
                // This is already a saved meal plan, just complete
                await completeWorkflow()
            }
        } catch {
            await handleGenerationError(error)
        }
    }
    
    /// Cancel current generation workflow
    func cancelGeneration() {
        print("❌ [AIGenerationManager] Cancelling generation")
        
        generationTask?.cancel()
        resetState()
    }
    
    /// Reset to initial state
    func resetState() {
        print("🔄 [AIGenerationManager] Resetting state")
        
        state = .idle
        workflowStep = .input
        error = nil
        isLoading = false
        previewMealPlan = nil
        previewWeeklyGrid = nil
        currentRequest = nil
        generationTask?.cancel()
        generationTask = nil
    }
    
    /// Handle error with recovery options
    func handleError(_ error: AIWorkflowError) async {
        print("❌ [AIGenerationManager] Handling error: \(error)")
        
        self.error = error
        self.isLoading = false
        
        // Determine appropriate state based on error type
        switch error {
        case .previewUnavailable, .invalidRequest:
            self.state = .idle
            self.workflowStep = .input
        case .generationFailed, .networkError, .timeout:
            self.state = .error(error.localizedDescription)
        case .applyFailed:
            self.state = .previewing  // Stay in preview to allow retry
        case .cancelled:
            resetState()
        case .unknown:
            self.state = .error(error.localizedDescription)
        }
    }
    
    /// Execute recovery action based on error and current state
    func executeRecoveryAction(_ action: AIWorkflowRecoveryAction) async {
        print("🔄 [AIGenerationManager] Executing recovery action: \(action)")
        
        error = nil
        
        switch action {
        case .retry:
            if let request = currentRequest {
                await retryGeneration(request)
            }
        case .regenerate:
            if let request = currentRequest {
                await generateMealPlan(request)
            }
        case .goBack:
            workflowStep = .input
            state = .idle
            isLoading = false
        case .startOver:
            resetState()
        case .dismiss:
            resetState()
        }
    }
    
    // MARK: - Private Implementation
    
    private func executeGeneration(_ request: AIGenerationRequest) async {
        do {
            print("🔄 [AIGenerationManager] Executing generation request")
            
            // Phase 1: Generate meal plan with RecipeStubs (fast)
            let generatedPlan = try await mealPlanService.generateCustomMealPlan(
                description: request.description,
                dietType: request.dietType,
                allergies: request.allergies,
                dislikes: request.dislikes,
                calorieTarget: request.calorieTarget,
                additionalRequirements: request.additionalRequirements
            )
            
            await handleGenerationSuccess(generatedPlan)
            
        } catch {
            await handleGenerationError(error)
        }
    }
    
    private func handleGenerationSuccess(_ generatedPlan: MealPlan) async {
        print("✅ [AIGenerationManager] Generation completed successfully")
        
        // Store the generated meal plan directly
        previewMealPlan = generatedPlan
        previewWeeklyGrid = MealPlanConverter.mealPlanToGrid(generatedPlan)
        
        state = .previewing
        workflowStep = .preview
        isLoading = false
        
        print("📋 [AIGenerationManager] Preview data ready - Meal plan: \(generatedPlan.name)")
    }
    
    private func handleGenerationError(_ error: Error) async {
        print("❌ [AIGenerationManager] Generation error: \(error)")
        
        let workflowError: AIWorkflowError
        
        if let aiError = error as? AIWorkflowError {
            workflowError = aiError
        } else {
            // Convert generic errors to workflow errors
            let errorMessage = error.localizedDescription
            if errorMessage.lowercased().contains("network") || errorMessage.lowercased().contains("connection") {
                workflowError = .networkError(errorMessage)
            } else if errorMessage.lowercased().contains("timeout") {
                workflowError = .timeout
            } else {
                workflowError = .generationFailed(errorMessage)
            }
        }
        
        await handleError(workflowError)
    }
    
    private func retryGeneration(_ request: AIGenerationRequest) async {
        print("🔄 [AIGenerationManager] Retrying generation")
        
        // Reset error state and retry
        error = nil
        isLoading = true
        
        await executeGeneration(request)
    }
    
    private func completeWorkflow() async {
        print("🎉 [AIGenerationManager] Workflow completed successfully")
        
        state = .idle
        workflowStep = .completed
        isLoading = false
        
        // Clear preview data after successful application
        previewMealPlan = nil
        previewWeeklyGrid = nil
        currentRequest = nil
    }
    
    private func completeWorkflowWithPlan(_ confirmedPlan: MealPlan) async {
        print("🎉 [AIGenerationManager] Workflow completed with confirmed plan: \(confirmedPlan.name)")
        
        // Update the preview meal plan with the confirmed version
        previewMealPlan = confirmedPlan
        
        state = .idle
        workflowStep = .completed
        isLoading = false
        
        // Keep the confirmed plan available for a short time before clearing
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            previewMealPlan = nil
            previewWeeklyGrid = nil
            currentRequest = nil
        }
    }
    
    // MARK: - Helper Methods
    
    /// Determine if a meal plan is a preview (AI-generated, not yet saved to backend)
    private func isPreviewMealPlan(_ mealPlan: MealPlan) -> Bool {
        // AI-generated meal plans typically have these characteristics:
        // 1. ID contains "ai-generated" or is a UUID generated by AI service
        // 2. dailyMeals contains RecipeStub data instead of full Recipe objects
        // 3. No items array (backend meal plans have items)
        
        if mealPlan.id.contains("ai-generated") || mealPlan.id.isEmpty {
            return true
        }
        
        // Check if this meal plan has lightweight daily meals (AI-generated characteristic)
        if mealPlan.dailyMeals != nil && mealPlan.items == nil {
            return true
        }
        
        return false
    }
    
    // MARK: - Computed Properties
    
    var canProceed: Bool {
        switch workflowStep {
        case .input:
            return currentRequest != nil
        case .preview:
            return previewMealPlan != nil && !isLoading
        case .generating, .confirming, .completed:
            return false
        }
    }
    
    var canGoBack: Bool {
        switch workflowStep {
        case .preview:
            return !isLoading
        case .input, .generating, .confirming, .completed:
            return false
        }
    }
    
    var canCancel: Bool {
        switch workflowStep {
        case .generating, .preview:
            return true
        case .input, .confirming, .completed:
            return false
        }
    }
    
    var workflowProgress: Double {
        switch workflowStep {
        case .input:
            return 0.0
        case .generating:
            return 0.3
        case .preview:
            return 0.6
        case .confirming:
            return 0.9
        case .completed:
            return 1.0
        }
    }
}

// MARK: - Meal Plan Converter (Consolidated Logic)

struct MealPlanConverter {
    
    /// Convert MealPlan to WeeklyMealGrid (consolidated from multiple implementations)
    static func mealPlanToGrid(_ mealPlan: MealPlan) -> WeeklyMealGrid {
        var grid = WeeklyMealGrid()
        
        // Handle AI-generated meal plans with dailyMeals (RecipeStub-based)
        if let dailyMeals = mealPlan.dailyMeals {
            for (dayIndex, dailyMeal) in dailyMeals.enumerated() {
                if dayIndex < grid.dailyMeals.count {
                    // dailyMeal contains Recipe objects directly
                    grid.dailyMeals[dayIndex].breakfast = dailyMeal.breakfast
                    grid.dailyMeals[dayIndex].lunch = dailyMeal.lunch
                    grid.dailyMeals[dayIndex].dinner = dailyMeal.dinner
                }
            }
            return grid
        }
        
        // Handle regular meal plans with items (MealPlanItem-based)
        if let items = mealPlan.items {
            for item in items {
                guard let recipe = item.recipe,
                      item.dayOfWeek < grid.dailyMeals.count else { continue }
                
                switch item.mealType.lowercased() {
                case "breakfast":
                    grid.dailyMeals[item.dayOfWeek].breakfast.append(recipe)
                case "lunch":
                    grid.dailyMeals[item.dayOfWeek].lunch.append(recipe)
                case "dinner":
                    grid.dailyMeals[item.dayOfWeek].dinner.append(recipe)
                default:
                    break
                }
            }
        }
        
        return grid
    }
    
    /// Convert RecipeStubs to full Recipes (for Phase 2 of two-phase workflow)
    static func convertStubsToRecipes(_ stubs: [RecipeStub]) async throws -> [Recipe] {
        // This will be implemented when we integrate with the backend apply meal endpoint
        // For now, return empty array as this conversion happens server-side
        return []
    }
}

// MARK: - Supporting Types

extension AIGenerationManager {
    
    /// Get available recovery actions for current error
    func getRecoveryActions() -> [AIWorkflowRecoveryAction] {
        guard let error = error else { return [] }
        
        let config = AIWorkflowErrorAlertConfig(error: error, currentStep: workflowStep)
        var actions = [config.primaryAction]
        if let secondary = config.secondaryAction {
            actions.append(secondary)
        }
        return actions
    }
}