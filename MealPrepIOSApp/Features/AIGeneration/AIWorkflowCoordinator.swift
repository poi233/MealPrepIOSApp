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
    // REMOVED: Local state variables - now using AIGenerationService as single source of truth

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

        // Observe AI generation service state directly
        mealPlanStore.aiGenerationService.$aiGenerationState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                print("🔔 [AIWorkflowCoordinator] State observer triggered: \(state)")
                self?.handleStoreStateChange(state)
            }
            .store(in: &cancellables)

        // Observe preview meal plan changes from service
        mealPlanStore.aiGenerationService.$previewMealPlan
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
        // Check if AIGenerationService has preview data ready
        guard let mealPlan = mealPlanStore.aiGenerationService.previewMealPlan,
              let previewGrid = mealPlanStore.aiGenerationService.previewWeeklyGrid else {
            print("❌ [AIWorkflowCoordinator] No preview data available in AIGenerationService")
            print("🔍 [AIWorkflowCoordinator] Service previewMealPlan: \(mealPlanStore.aiGenerationService.previewMealPlan?.name ?? "nil")")
            print("🔍 [AIWorkflowCoordinator] Service previewWeeklyGrid: \(mealPlanStore.aiGenerationService.previewWeeklyGrid != nil)")
            print("🔍 [AIWorkflowCoordinator] Service AI generation state: \(mealPlanStore.aiGenerationService.aiGenerationState)")
            handleWorkflowError(.previewUnavailable)
            return
        }

        print("📋 [AIWorkflowCoordinator] Moving to preview step with meal plan: \(mealPlan.name)")
        print("📋 [AIWorkflowCoordinator] Preview grid has \(previewGrid.dailyMeals.count) days")

        // Log preview data for debugging
        for (index, day) in previewGrid.dailyMeals.enumerated() {
            print("📋 [AIWorkflowCoordinator] Preview Grid Day \(index) (\(day.day)): \(day.breakfast.count) breakfast, \(day.lunch.count) lunch, \(day.dinner.count) dinner")
        }

        print("✅ [AIWorkflowCoordinator] Preview data validated successfully")

        currentStep = .preview
        isLoading = false
        canCancel = true
    }

    /// Apply the previewed meal plan
    func applyMealPlan() {
        guard mealPlanStore.aiGenerationService.previewMealPlan != nil,
              mealPlanStore.aiGenerationService.previewWeeklyGrid != nil else {
            handleWorkflowError(.applyFailed("No preview data available to apply"))
            return
        }

        print("✅ [AIWorkflowCoordinator] Applying meal plan")

        currentStep = .confirming
        isLoading = true
        canCancel = false

        Task {
            do {

                print("🔄 [AIWorkflowCoordinator] Starting confirmPreviewMealPlan...")
                print("🔍 [AIWorkflowCoordinator] State before confirmPreviewMealPlan: \(mealPlanStore.aiGenerationState)")
                print("🔍 [AIWorkflowCoordinator] Preview meal plan exists: \(mealPlanStore.previewMealPlan != nil)")

                await mealPlanStore.confirmPreviewMealPlan()

                print("✅ [AIWorkflowCoordinator] confirmPreviewMealPlan completed")
                print("🔍 [AIWorkflowCoordinator] State immediately after confirmPreviewMealPlan: \(mealPlanStore.aiGenerationState)")

                // Give a small delay to ensure state changes propagate properly
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                await MainActor.run {
                    print("🔍 [AIWorkflowCoordinator] State after 0.1s delay: \(mealPlanStore.aiGenerationState)")
                    print("🔍 [AIWorkflowCoordinator] Current meal plans count: \(mealPlanStore.mealPlans.count)")
                    print("🔍 [AIWorkflowCoordinator] Active meal plan: \(mealPlanStore.activeMealPlan?.name ?? "none")")
                    print("🔍 [AIWorkflowCoordinator] Preview meal plan after apply: \(mealPlanStore.previewMealPlan?.name ?? "none")")

                    // Check if the operation was successful
                    switch mealPlanStore.aiGenerationState {
                    case .idle:
                        print("✅ [AIWorkflowCoordinator] State is idle, completing workflow")
                        completeWorkflow()
                    case .error(let error):
                        print("❌ [AIWorkflowCoordinator] State shows error: \(error)")
                        handleWorkflowError(.applyFailed(error))
                    case .confirming:
                        print("⏳ [AIWorkflowCoordinator] Still confirming, waiting for completion...")
                        print("🔍 [AIWorkflowCoordinator] Will wait for state observer to handle completion")
                        // Still in progress, let the state observer handle completion
                    case .previewing:
                        print("⚠️ [AIWorkflowCoordinator] Unexpectedly back to previewing state")
                        print("🔍 [AIWorkflowCoordinator] This suggests confirmPreviewMealPlan didn't properly transition to .idle")
                        print("🔍 [AIWorkflowCoordinator] Checking if recipes were actually created...")
                        print("🔍 [AIWorkflowCoordinator] Will wait additional 0.5s for potential delayed state change")

                        // Wait a bit longer to see if the state updates
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            print("🔍 [AIWorkflowCoordinator] Final state check after 0.5s delay: \(self.mealPlanStore.aiGenerationState)")

                            switch self.mealPlanStore.aiGenerationState {
                            case .idle:
                                print("✅ [AIWorkflowCoordinator] State eventually became idle, completing workflow")
                                self.completeWorkflow()
                            default:
                                print("⚠️ [AIWorkflowCoordinator] State is still \(self.mealPlanStore.aiGenerationState) after delay")
                                // Let's check if the operation actually succeeded despite the state
                                if self.mealPlanStore.mealPlans.count > 0 {
                                    print("✅ [AIWorkflowCoordinator] Meal plans exist (\(self.mealPlanStore.mealPlans.count)), operation succeeded despite state")
                                    self.completeWorkflow()
                                } else {
                                    print("❌ [AIWorkflowCoordinator] No meal plans found, operation appears to have failed")
                                    self.handleWorkflowError(.applyFailed("Operation completed but state is unclear. Please try again."))
                                }
                            }
                        }
                    case .generating:
                        print("⚠️ [AIWorkflowCoordinator] Unexpectedly back to generating state")
                        print("🔍 [AIWorkflowCoordinator] This is highly unusual - generation shouldn't be active during apply")
                        handleWorkflowError(.applyFailed("Operation completed but state is unclear. Please try again."))
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ [AIWorkflowCoordinator] Exception during apply: \(error)")
                    handleWorkflowError(.applyFailed("Failed to apply meal plan: \(error.localizedDescription)"))
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

        // Clear previous results in service
        mealPlanStore.aiGenerationService.resetAIGenerationState()

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
        workflowStartTime = nil
        canCancel = true

        // Reset store state
        mealPlanStore.resetAIGenerationState()
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
        print("🔍 [AIWorkflowCoordinator] Current workflow step: \(currentStep)")
        print("🔍 [AIWorkflowCoordinator] Current isLoading: \(isLoading)")

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
            print("🔍 [AIWorkflowCoordinator] State is idle, current step: \(currentStep)")
            if currentStep == .confirming {
                print("✅ [AIWorkflowCoordinator] Confirming step completed successfully, transitioning to complete")
                completeWorkflow()
            } else {
                print("🔍 [AIWorkflowCoordinator] State is idle but step is \(currentStep), not confirming")
            }
        }
    }

    private func handlePreviewMealPlanChange(_ mealPlan: MealPlan?) {
        print("📋 [AIWorkflowCoordinator] Preview meal plan changed: \(mealPlan?.name ?? "nil"), current step: \(currentStep)")

        if let _ = mealPlan, currentStep == .generating {
            print("📋 [AIWorkflowCoordinator] Meal plan available, checking if weekly grid is also ready...")

            // Check if weekly grid is also available
            if let weeklyGrid = mealPlanStore.aiGenerationService.previewWeeklyGrid {
                print("📋 [AIWorkflowCoordinator] Weekly grid is ready with \(weeklyGrid.dailyMeals.count) days")
                print("📋 [AIWorkflowCoordinator] Waiting for state change to proceed to preview")
            } else {
                print("⚠️ [AIWorkflowCoordinator] Weekly grid not yet available, waiting...")
            }
        }
    }

    // MARK: - Helper Methods
    // REMOVED: convertMealPlanToGrid - now centralized in AIGenerationService

    // MARK: - Computed Properties

    var canProceed: Bool {
        switch currentStep {
        case .input:
            return generationRequest != nil
        case .preview:
            return mealPlanStore.aiGenerationService.previewMealPlan != nil && !isLoading
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
    // weekStartDate removed - dates will be determined by WeeklyMealGrid structure
    let additionalRequirements: String?

    init(
        description: String,
        dietType: DietType? = nil,
        allergies: [String] = [],
        dislikes: [String] = [],
        calorieTarget: Int? = nil,
        // weekStartDate parameter removed
        additionalRequirements: String? = nil
    ) {
        self.description = description
        self.dietType = dietType
        self.allergies = allergies
        self.dislikes = dislikes
        self.calorieTarget = calorieTarget
        // weekStartDate assignment removed
        self.additionalRequirements = additionalRequirements
    }
}