//
//  AIWeeklyWorkflowView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/28/25.
//

import SwiftUI

/// Main workflow controller for AI Weekly Meal Plan generation
/// Manages the complete flow: Input → Generation → Preview → Confirmation
struct AIWeeklyWorkflowView: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @EnvironmentObject var recipeStore: RecipeStore
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Workflow Coordinator - Initialize with empty stores, update in onAppear
    @StateObject private var coordinator = AIWorkflowCoordinator(
        mealPlanStore: MealPlanStore(),
        recipeStore: RecipeStore()
    )
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                // Main content based on current step
                switch coordinator.currentStep {
                case .input:
                    inputStepView
                case .generating:
                    generatingStepView
                case .preview:
                    previewStepView
                case .confirming:
                    confirmingStepView
                case .completed:
                    completedStepView
                }
            }
            .navigationTitle(coordinator.stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if coordinator.canCancel {
                        Button("Cancel") {
                            coordinator.cancelWorkflow()
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if coordinator.canGoBack {
                        Button("Back") {
                            coordinator.currentStep = .input
                        }
                        .foregroundColor(.primaryGreen)
                    }
                }
            }
            .alert("Error", isPresented: $coordinator.showingError) {
                Button("Try Again") {
                    coordinator.retryCurrentOperation()
                }
                Button("Cancel", role: .cancel) {
                    coordinator.resetWorkflow()
                }
            } message: {
                Text(coordinator.errorMessage ?? "An unexpected error occurred")
            }
        }
        .onAppear {
            // Update coordinator with environment objects
            coordinator.updateDependencies(mealPlanStore: mealPlanStore, recipeStore: recipeStore)
        }
    }
    
    // MARK: - Input Step
    private var inputStepView: some View {
        EnhancedAIGenerationInputView(
            onGenerationStart: { request in
                coordinator.startGeneration(with: request)
            },
            onCancel: {
                coordinator.cancelWorkflow()
                dismiss()
            }
        )
        .environmentObject(mealPlanStore)
        .environmentObject(recipeStore)
    }
    
    // MARK: - Generating Step
    private var generatingStepView: some View {
        VStack(spacing: 32) {
            // Progress indicator
            VStack(spacing: 16) {
                ProgressView(value: coordinator.workflowProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .primaryGreen))
                    .scaleEffect(y: 2)
                    .padding(.horizontal, 40)
                
                Text("Step \(coordinator.currentStep.stepNumber) of \(coordinator.currentStep.totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // AI Generation Animation
            AIGenerationLoadingView()
            
            VStack(spacing: 12) {
                Text(coordinator.stepTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(coordinator.stepDescription)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Status indicator
            if coordinator.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("This may take a few moments...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 16)
            }
            
            Spacer(minLength: 20)
            
            // Cancel button
            if coordinator.canCancel {
                Button("Cancel Generation") {
                    coordinator.cancelWorkflow()
                    dismiss()
                }
                .subtleGreenButton()
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Preview Step
    private var previewStepView: some View {
        Group {
            if let previewPlan = mealPlanStore.aiGenerationService.previewMealPlan {
                AIWeeklyPreviewView(generatedMealPlan: previewPlan)
                    .navigationBarHidden(true)
                    .overlay(alignment: .bottom) {
                        // Custom bottom bar for workflow integration
                        previewBottomBar
                    }
            } else {
                // Fallback loading state
                generatingStepView
            }
        }
    }
    
    // MARK: - Confirming Step
    private var confirmingStepView: some View {
        VStack(spacing: 32) {
            // Progress indicator
            VStack(spacing: 16) {
                ProgressView(value: coordinator.workflowProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .primaryGreen))
                    .scaleEffect(y: 2)
                    .padding(.horizontal, 40)
                
                Text("Step \(coordinator.currentStep.stepNumber) of \(coordinator.currentStep.totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Success animation
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.primaryGreen)
                .symbolEffect(.bounce, options: .repeating)
            
            VStack(spacing: 12) {
                Text(coordinator.stepTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(coordinator.stepDescription)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Loading indicator
            if coordinator.isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primaryGreen))
                        .scaleEffect(1.2)
                    
                    Text("Please wait...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 16)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Completed Step
    private var completedStepView: some View {
        VStack(spacing: 32) {
            // Progress indicator (completed)
            VStack(spacing: 16) {
                ProgressView(value: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .primaryGreen))
                    .scaleEffect(y: 2)
                    .padding(.horizontal, 40)
                
                Text("Completed!")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryGreen)
            }
            
            // Success animation
            Image(systemName: "party.popper.fill")
                .font(.system(size: 80))
                .foregroundColor(.primaryGreen)
                .symbolEffect(.bounce)
            
            VStack(spacing: 12) {
                Text(coordinator.stepTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(coordinator.stepDescription)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Spacer(minLength: 20)
            
            // Action buttons
            VStack(spacing: 12) {
                Button("View Meal Plan") {
                    dismiss()
                }
                .primaryGreenButton()
                
                Button("Generate Another") {
                    coordinator.resetWorkflow()
                }
                .subtleGreenButton()
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Supporting Views
    
    private var previewBottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 16) {
                Button("Regenerate") {
                    coordinator.regenerateMealPlan()
                }
                .subtleGreenButton()
                .frame(maxWidth: .infinity)
                
                Button(coordinator.isLoading ? "Applying..." : "Apply Plan") {
                    coordinator.applyMealPlan()
                }
                .primaryGreenButton()
                .frame(maxWidth: .infinity)
                .disabled(coordinator.isLoading || !coordinator.canProceed)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Enhanced Generation Input View

/// Enhanced version of AIWeeklyGenerationView with workflow callbacks
struct EnhancedAIGenerationInputView: View {
    let onGenerationStart: (AIGenerationRequest) -> Void
    let onCancel: () -> Void
    
    @EnvironmentObject var mealPlanStore: MealPlanStore
    
    var body: some View {
        // We'll create a custom input view or enhance the existing one
        AIWeeklyGenerationViewWithCallbacks(
            onGenerationStart: onGenerationStart,
            onCancel: onCancel
        )
    }
}

// MARK: - AI Generation Loading View

struct AIGenerationLoadingView: View {
    @State private var animateGradient = false
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            .primaryGreen.opacity(0.1),
                            .primaryGreen.opacity(0.2),
                            .primaryGreen.opacity(0.1)
                        ],
                        startPoint: animateGradient ? .topLeading : .bottomTrailing,
                        endPoint: animateGradient ? .bottomTrailing : .topLeading
                    )
                )
                .frame(width: 200, height: 200)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateGradient)
            
            // AI brain icon with rotation
            Image(systemName: "brain")
                .font(.system(size: 60))
                .foregroundColor(.primaryGreen)
                .rotationEffect(.degrees(rotationAngle))
                .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: rotationAngle)
            
            // Floating particles
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(.primaryGreen.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .offset(
                        x: cos(Double(index) * 2 * .pi / 5) * 80,
                        y: sin(Double(index) * 2 * .pi / 5) * 80
                    )
                    .rotationEffect(.degrees(rotationAngle + Double(index * 72)))
                    .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: rotationAngle)
            }
        }
        .onAppear {
            animateGradient = true
            rotationAngle = 360
        }
    }
}



// MARK: - Preview
#Preview {
    AIWeeklyWorkflowView()
        .environmentObject(MealPlanStore())
        .environmentObject(RecipeStore())
}