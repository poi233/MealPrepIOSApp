//
//  AIWorkflowCoordinator.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/28/25.
//

import SwiftUI
import Combine

/// Coordinator for AI Meal Plan Generation Workflow
/// Manages the complete flow: Input → Generation → Preview → Confirmation
@MainActor
class AIWorkflowCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentStep: AIWorkflowStep = .input
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingError = false
    
    // MARK: - Workflow Data
    @Published var generationRequest: AIGenerationRequest?
    @Published var generatedMealPlan: MealPlan?
    @Published var previewGrid: WeeklyMealGrid?
    
    // MARK: - Dependencies
    private var mealPlanStore: MealPlanStore
    private var recipeStore: RecipeStore
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Workflow State
    private var workflowStartTime: Date?
    @Published var canCancel = true
    
    // MARK: - Initialization
    init(mealPlanStore: MealPlanStore, recipeStore: RecipeStore) {
        self.mealPlanStore = mealPlanStore
        self.recipeStore = recipeStore
        setupObservers()
    }
    
    // MARK: - Dependencies Update
    func updateDependencies(mealPlanStore: MealPlanStore, recipeStore: RecipeStore) {
        self.mealPlanStore = mealPlanStore
        self.recipeStore = recipeStore
        setupObservers()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Clear existing observers
        cancellables.removeAll()
        
        // Observe meal plan store AI generation state
        mealPlanStore.$aiGenerationState
            .sink { [weak self] state in
                self?.handleStoreStateChange(state)
            }
            .store(in: &cancellables)
        
        // Observe preview meal plan changes
        mealPlanStore.$previewMealPlan
            .sink { [weak self] mealPlan in
                self?.handlePreviewMealPlanChange(mealPlan)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Workflow Control
    
    /// Start the AI generation workflow with user input
    func startGeneration(with request: AIGenerationRequest) {
        print("🚀 [AIWorkflowCoordinator] Starting generation workflow")
        
        generationRequest = request
        currentStep = .generating
        isLoading = true
        errorMessage = nil
        workflowStartTime = Date()
        canCancel = true
        
        Task {
            print("🚀 [AIWorkflowCoordinator] Calling generateCustomMealPlan...")
            
            print("🚀 [AIWorkflowCoordinator] About to call generateCustomMealPlan...")
            print("🚀 [AIWorkflowCoordinator] MealPlanStore instance: \(mealPlanStore)")
            
            let success = await mealPlanStore.generateCustomMealPlan(
                description: request.description,
                dietType: request.dietType,
                allergies: request.allergies,
                dislikes: request.dislikes,
                calorieTarget: request.calorieTarget,
                weekStartDate: request.weekStartDate,
                additionalRequirements: request.additionalRequirements
            )
            
            print("🚀 [AIWorkflowCoordinator] Call completed, success: \(success)")
            
            print("🚀 [AIWorkflowCoordinator] generateCustomMealPlan returned: \(success)")
            
            if !success {
                await MainActor.run {
                    handleWorkflowError(.generationFailed("Failed to generate meal plan. Please check your connection and try again."))
                }
            } else {
                print("🚀 [AIWorkflowCoordinator] Generation successful, waiting for state change...")
                
                // Check the current state after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🔍 [AIWorkflowCoordinator] Current state after generation: \(self.mealPlanStore.aiGenerationState)")
                    print("🔍 [AIWorkflowCoordinator] Preview meal plan exists: \(self.mealPlanStore.previewMealPlan != nil)")
                    if let previewPlan = self.mealPlanStore.previewMealPlan {
                        print("🔍 [AIWorkflowCoordinator] Preview plan name: \(previewPlan.name)")
                        print("🔍 [AIWorkflowCoordinator] Preview plan daily meals count: \(previewPlan.dailyMeals?.count ?? 0)")
                    }
                }
            }
        }
    }
    
    /// Move to preview step with generated meal plan
    func proceedToPreview() {
        // Try to get meal plan from store first, then from local state
        let mealPlan = mealPlanStore.previewMealPlan ?? generatedMealPlan
        
        guard let mealPlan = mealPlan else {
            print("❌ [AIWorkflowCoordinator] No meal plan available for preview")
            handleWorkflowError(.previewUnavailable)
            return
        }
        
        print("📋 [AIWorkflowCoordinator] Moving to preview step with meal plan: \(mealPlan.name)")
        print("📋 [AIWorkflowCoordinator] Meal plan has dailyMeals: \(mealPlan.dailyMeals != nil)")
        print("📋 [AIWorkflowCoordinator] Daily meals count: \(mealPlan.dailyMeals?.count ?? 0)")
        
        generatedMealPlan = mealPlan
        previewGrid = convertMealPlanToGrid(mealPlan)
        currentStep = .preview
        isLoading = false
        canCancel = true
    }
    
    /// Apply the previewed meal plan
    func applyMealPlan() {
        guard generatedMealPlan != nil else {
            handleWorkflowError(.applyFailed("No meal plan available to apply"))
            return
        }
        
        print("✅ [AIWorkflowCoordinator] Applying meal plan")
        
        currentStep = .confirming
        isLoading = true
        canCancel = false
        
        Task {
            let success = await mealPlanStore.applyPreviewMealPlan()
            
            await MainActor.run {
                if success {
                    completeWorkflow()
                } else {
                    handleWorkflowError(.applyFailed("Failed to apply meal plan. Please try again."))
                }
            }
        }
    }
    
    /// Regenerate meal plan with same parameters
    func regenerateMealPlan() {
        guard let request = generationRequest else {
            handleWorkflowError(.invalidRequest("No generation parameters available for regeneration"))
            return
        }
        
        print("🔄 [AIWorkflowCoordinator] Regenerating meal plan")
        
        // Clear previous results
        generatedMealPlan = nil
        previewGrid = nil
        
        // Restart generation
        startGeneration(with: request)
    }
    
    /// Complete the workflow successfully
    func completeWorkflow() {
        print("🎉 [AIWorkflowCoordinator] Workflow completed successfully")
        
        currentStep = .completed
        isLoading = false
        canCancel = false
        
        // Log workflow completion time
        if let startTime = workflowStartTime {
            let duration = Date().timeIntervalSince(startTime)
            print("⏱️ [AIWorkflowCoordinator] Total workflow time: \(String(format: "%.1f", duration))s")
        }
    }
    
    /// Cancel the current workflow
    func cancelWorkflow() {
        guard canCancel else {
            print("⚠️ [AIWorkflowCoordinator] Cannot cancel at current step")
            return
        }
        
        print("❌ [AIWorkflowCoordinator] Workflow cancelled by user")
        
        // Cancel any ongoing generation
        mealPlanStore.cancelAIGeneration()
        
        // Reset workflow state
        resetWorkflow()
    }
    
    /// Reset workflow to initial state
    func resetWorkflow() {
        print("🔄 [AIWorkflowCoordinator] Resetting workflow")
        
        currentStep = .input
        isLoading = false
        errorMessage = nil
        showingError = false
        generationRequest = nil
        generatedMealPlan = nil
        previewGrid = nil
        workflowStartTime = nil
        canCancel = true
        
        // Reset store state
        mealPlanStore.resetAIGeneration()
    }
    
    /// Handle workflow errors with enhanced error handling
    func handleError(_ message: String) {
        let error = AIWorkflowError.unknown(message)
        handleWorkflowError(error)
    }
    

    
    /// Retry current operation
    func retryCurrentOperation() {
        showingError = false
        errorMessage = nil
        
        switch currentStep {
        case .input:
            if let request = generationRequest {
                startGeneration(with: request)
            }
        case .preview:
            applyMealPlan()
        default:
            break
        }
    }
    
    // MARK: - State Change Handlers
    
    private func handleStoreStateChange(_ state: AIGenerationState) {
        print("🔄 [AIWorkflowCoordinator] Store state changed to: \(state)")
        
        switch state {
        case .generating:
            if currentStep == .input {
                currentStep = .generating
                isLoading = true
            }
            
        case .previewing:
            print("📋 [AIWorkflowCoordinator] Store state is previewing, current step: \(currentStep)")
            if currentStep == .generating {
                proceedToPreview()
            }
            
        case .confirming:
            if currentStep == .preview {
                currentStep = .confirming
                isLoading = true
            }
            
        case .error(let message):
            // Try to categorize the error based on message content
            let workflowError: AIWorkflowError
            if message.lowercased().contains("network") || message.lowercased().contains("connection") {
                workflowError = .networkError(message)
            } else if message.lowercased().contains("timeout") {
                workflowError = .timeout
            } else {
                workflowError = .generationFailed(message)
            }
            handleWorkflowError(workflowError)
            
        case .idle:
            if currentStep == .confirming {
                completeWorkflow()
            }
        }
    }
    
    private func handlePreviewMealPlanChange(_ mealPlan: MealPlan?) {
        print("📋 [AIWorkflowCoordinator] Preview meal plan changed: \(mealPlan?.name ?? "nil"), current step: \(currentStep)")
        
        if let mealPlan = mealPlan, currentStep == .generating {
            generatedMealPlan = mealPlan
            previewGrid = convertMealPlanToGrid(mealPlan)
            // Don't call proceedToPreview here to avoid double calls
            print("📋 [AIWorkflowCoordinator] Meal plan stored, waiting for state change to proceed")
        }
    }
    
    // MARK: - Helper Methods
    
    private func convertMealPlanToGrid(_ mealPlan: MealPlan) -> WeeklyMealGrid {
        var grid = WeeklyMealGrid(weekStartDate: mealPlan.weekStartDate)
        
        // Handle AI-generated meal plans with dailyMeals
        if let dailyMeals = mealPlan.dailyMeals {
            for (dayIndex, dailyMeal) in dailyMeals.enumerated() {
                if dayIndex < grid.dailyMeals.count {
                    // Now dailyMeal contains Recipe objects directly
                    grid.dailyMeals[dayIndex].breakfast = dailyMeal.breakfast
                    grid.dailyMeals[dayIndex].lunch = dailyMeal.lunch
                    grid.dailyMeals[dayIndex].dinner = dailyMeal.dinner
                }
            }
            return grid
        }
        
        // Handle regular meal plans with items
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
    
    // REMOVED: createRecipeFromMealItem - no longer needed as dailyMeals now contains Recipe objects directly
    
    // MARK: - Computed Properties
    
    var canProceed: Bool {
        switch currentStep {
        case .input:
            return generationRequest != nil
        case .preview:
            return generatedMealPlan != nil && !isLoading
        default:
            return false
        }
    }
    
    var canGoBack: Bool {
        switch currentStep {
        case .preview:
            return !isLoading
        default:
            return false
        }
    }
    
    var workflowProgress: Double {
        switch currentStep {
        case .input:
            return 0.0
        case .generating:
            return 0.25
        case .preview:
            return 0.5
        case .confirming:
            return 0.75
        case .completed:
            return 1.0
        }
    }
    
    var stepTitle: String {
        switch currentStep {
        case .input:
            return "Create Your Plan"
        case .generating:
            return "Generating..."
        case .preview:
            return "Review & Edit"
        case .confirming:
            return "Applying..."
        case .completed:
            return "Complete!"
        }
    }
    
    var stepDescription: String {
        switch currentStep {
        case .input:
            return "Tell us about your ideal meal plan"
        case .generating:
            return "AI is creating personalized meals for you"
        case .preview:
            return "Review and customize your meal plan"
        case .confirming:
            return "Saving your meal plan"
        case .completed:
            return "Your meal plan is ready!"
        }
    }
}

// MARK: - Supporting Types

enum AIWorkflowStep: CaseIterable {
    case input
    case generating
    case preview
    case confirming
    case completed
    
    var stepNumber: Int {
        switch self {
        case .input: return 1
        case .generating: return 2
        case .preview: return 3
        case .confirming: return 4
        case .completed: return 5
        }
    }
    
    var totalSteps: Int {
        return AIWorkflowStep.allCases.count
    }
}

// MARK: - AI Generation Request (keeping existing structure)
struct AIGenerationRequest {
    let description: String
    let dietType: DietType?
    let allergies: [String]
    let dislikes: [String]
    let calorieTarget: Int?
    let weekStartDate: Date
    let additionalRequirements: String?
    
    init(
        description: String,
        dietType: DietType? = nil,
        allergies: [String] = [],
        dislikes: [String] = [],
        calorieTarget: Int? = nil,
        weekStartDate: Date = Date(),
        additionalRequirements: String? = nil
    ) {
        self.description = description
        self.dietType = dietType
        self.allergies = allergies
        self.dislikes = dislikes
        self.calorieTarget = calorieTarget
        self.weekStartDate = weekStartDate
        self.additionalRequirements = additionalRequirements
    }
}