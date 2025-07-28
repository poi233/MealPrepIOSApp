//
//  AIWorkflowError.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/28/25.
//

import SwiftUI

// MARK: - AI Workflow Error Types

enum AIWorkflowError: LocalizedError, Equatable {
    case networkError(String)
    case generationFailed(String)
    case previewUnavailable
    case applyFailed(String)
    case invalidRequest(String)
    case timeout
    case cancelled
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network Error: \(message)"
        case .generationFailed(let message):
            return "Generation Failed: \(message)"
        case .previewUnavailable:
            return "Preview not available. Please try generating again."
        case .applyFailed(let message):
            return "Failed to apply meal plan: \(message)"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .timeout:
            return "Request timed out. Please check your connection and try again."
        case .cancelled:
            return "Operation was cancelled."
        case .unknown(let message):
            return "Unexpected error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Check your internet connection and try again."
        case .generationFailed:
            return "Try adjusting your preferences or generating again."
        case .previewUnavailable:
            return "Go back and generate a new meal plan."
        case .applyFailed:
            return "Check your storage space and try applying again."
        case .invalidRequest:
            return "Please fill in all required fields and try again."
        case .timeout:
            return "Try again with a more stable internet connection."
        case .cancelled:
            return "You can start a new generation if needed."
        case .unknown:
            return "Please try again or contact support if the problem persists."
        }
    }
    
    var canRetry: Bool {
        switch self {
        case .networkError, .generationFailed, .applyFailed, .timeout, .unknown:
            return true
        case .previewUnavailable, .invalidRequest, .cancelled:
            return false
        }
    }
    
    var shouldResetWorkflow: Bool {
        switch self {
        case .previewUnavailable, .invalidRequest:
            return true
        case .networkError, .generationFailed, .applyFailed, .timeout, .cancelled, .unknown:
            return false
        }
    }
}

// MARK: - Error Recovery Actions

enum AIWorkflowRecoveryAction {
    case retry
    case regenerate
    case goBack
    case startOver
    case dismiss
    
    var title: String {
        switch self {
        case .retry:
            return "Try Again"
        case .regenerate:
            return "Regenerate"
        case .goBack:
            return "Go Back"
        case .startOver:
            return "Start Over"
        case .dismiss:
            return "Cancel"
        }
    }
    
    var isDestructive: Bool {
        switch self {
        case .startOver, .dismiss:
            return true
        case .retry, .regenerate, .goBack:
            return false
        }
    }
}

// MARK: - Error Alert Configuration

struct AIWorkflowErrorAlertConfig {
    let error: AIWorkflowError
    let primaryAction: AIWorkflowRecoveryAction
    let secondaryAction: AIWorkflowRecoveryAction?
    
    init(error: AIWorkflowError, currentStep: AIWorkflowStep) {
        self.error = error
        
        // Determine appropriate actions based on error type and current step
        switch (error, currentStep) {
        case (.networkError, .generating), (.generationFailed, .generating), (.timeout, .generating):
            self.primaryAction = .retry
            self.secondaryAction = .startOver
            
        case (.networkError, .confirming), (.applyFailed, .confirming):
            self.primaryAction = .retry
            self.secondaryAction = .goBack
            
        case (.previewUnavailable, _):
            self.primaryAction = .regenerate
            self.secondaryAction = .startOver
            
        case (.invalidRequest, _):
            self.primaryAction = .goBack
            self.secondaryAction = .startOver
            
        case (.cancelled, _):
            self.primaryAction = .startOver
            self.secondaryAction = .dismiss
            
        default:
            self.primaryAction = .retry
            self.secondaryAction = .startOver
        }
    }
}

// MARK: - Enhanced Error Display Component

struct AIWorkflowErrorView: View {
    let error: AIWorkflowError
    let onAction: (AIWorkflowRecoveryAction) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private var config: AIWorkflowErrorAlertConfig {
        AIWorkflowErrorAlertConfig(error: error, currentStep: .input) // Default step for standalone view
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Error Icon
            Image(systemName: errorIcon)
                .font(.system(size: 60))
                .foregroundColor(.error)
                .symbolEffect(.bounce)
            
            // Error Message
            VStack(spacing: 12) {
                Text("Something went wrong")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(error.localizedDescription)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                }
            }
            
            // Action Buttons
            VStack(spacing: 12) {
                Button(config.primaryAction.title) {
                    onAction(config.primaryAction)
                }
                .primaryGreenButton()
                
                if let secondaryAction = config.secondaryAction {
                    Button(secondaryAction.title) {
                        onAction(secondaryAction)
                    }
                    .subtleGreenButton()
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var errorIcon: String {
        switch error {
        case .networkError, .timeout:
            return "wifi.exclamationmark"
        case .generationFailed, .previewUnavailable:
            return "brain.head.profile.error"
        case .applyFailed:
            return "exclamationmark.triangle"
        case .invalidRequest:
            return "questionmark.circle"
        case .cancelled:
            return "xmark.circle"
        case .unknown:
            return "exclamationmark.circle"
        }
    }
}

// MARK: - Error Toast Component

struct AIWorkflowErrorToast: View {
    let error: AIWorkflowError
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.error)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Error")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
        .onAppear {
            isVisible = true
            
            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }
}

// MARK: - Error Extension for AIWorkflowCoordinator

extension AIWorkflowCoordinator {
    
    /// Handle error with appropriate recovery actions
    func handleWorkflowError(_ error: AIWorkflowError) {
        print("❌ [AIWorkflowCoordinator] Workflow error: \(error)")
        
        errorMessage = error.localizedDescription
        showingError = true
        isLoading = false
        
        // Determine appropriate step based on error and recovery options
        if error.shouldResetWorkflow {
            currentStep = .input
        } else {
            // Stay on current step for retryable errors
            switch currentStep {
            case .generating:
                if case .generationFailed = error {
                    currentStep = .input
                }
            case .confirming:
                if case .applyFailed = error {
                    currentStep = .preview
                }
            default:
                break
            }
        }
    }
    
    /// Get available recovery actions for current error and step
    func getRecoveryActions(for error: AIWorkflowError) -> [AIWorkflowRecoveryAction] {
        let config = AIWorkflowErrorAlertConfig(error: error, currentStep: currentStep)
        var actions = [config.primaryAction]
        if let secondary = config.secondaryAction {
            actions.append(secondary)
        }
        return actions
    }
    
    /// Execute recovery action
    func executeRecoveryAction(_ action: AIWorkflowRecoveryAction) {
        showingError = false
        errorMessage = nil
        
        switch action {
        case .retry:
            retryCurrentOperation()
        case .regenerate:
            if let request = generationRequest {
                startGeneration(with: request)
            }
        case .goBack:
            switch currentStep {
            case .preview, .confirming:
                currentStep = .input
            default:
                currentStep = .input
            }
        case .startOver:
            resetWorkflow()
        case .dismiss:
            resetWorkflow()
        }
    }
}

// MARK: - Preview
#Preview("Error View") {
    AIWorkflowErrorView(
        error: .generationFailed("Failed to generate meal plan due to server error"),
        onAction: { action in
            print("Action: \(action)")
        }
    )
}

#Preview("Error Toast") {
    VStack {
        Spacer()
        AIWorkflowErrorToast(
            error: .networkError("Connection timeout"),
            onDismiss: {
                print("Toast dismissed")
            }
        )
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}