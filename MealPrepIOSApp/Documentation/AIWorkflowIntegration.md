# AI Weekly Meal Plan Workflow Integration

## Overview

This document describes the complete AI-powered meal plan generation workflow, including all components and their integration.

## Architecture

### Core Components

1. **AIWorkflowCoordinator** - Central state manager for the entire workflow
2. **AIWeeklyWorkflowView** - Main UI controller that orchestrates the flow
3. **AIWeeklyGenerationViewWithCallbacks** - Enhanced input view with callback support
4. **AIWeeklyPreviewView** - Preview and editing interface (existing)
5. **AIWorkflowError** - Comprehensive error handling system

### Workflow Steps

```
Input → Generation → Preview → Confirmation → Completion
  ↓         ↓          ↓           ↓            ↓
Step 1    Step 2     Step 3      Step 4       Step 5
```

## Usage

### Basic Integration

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var mealPlanStore = MealPlanStore()
    @StateObject private var recipeStore = RecipeStore()
    @State private var showingAIWorkflow = false
    
    var body: some View {
        NavigationView {
            VStack {
                Button("Generate AI Meal Plan") {
                    showingAIWorkflow = true
                }
                .primaryGreenButton()
            }
            .sheet(isPresented: $showingAIWorkflow) {
                AIWeeklyWorkflowView()
                    .environmentObject(mealPlanStore)
                    .environmentObject(recipeStore)
            }
        }
    }
}
```

### Advanced Customization

You can customize the workflow by creating your own coordinator instance:

```swift
struct CustomAIWorkflowView: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @EnvironmentObject var recipeStore: RecipeStore
    @StateObject private var coordinator: AIWorkflowCoordinator
    
    init() {
        _coordinator = StateObject(wrappedValue: AIWorkflowCoordinator(
            mealPlanStore: MealPlanStore(),
            recipeStore: RecipeStore()
        ))
    }
    
    var body: some View {
        // Custom UI based on coordinator.currentStep
        VStack {
            Text("Current Step: \\(coordinator.stepTitle)")
            
            ProgressView(value: coordinator.workflowProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .primaryGreen))
            
            // Custom step handling...
        }
        .onAppear {
            coordinator.updateDependencies(
                mealPlanStore: mealPlanStore,
                recipeStore: recipeStore
            )
        }
    }
}
```

## Workflow States

### AIWorkflowStep

- `.input` - User fills out meal plan preferences
- `.generating` - AI is creating the meal plan
- `.preview` - User reviews and can edit the generated plan
- `.confirming` - Applying the meal plan to the user's current week
- `.completed` - Success state with options to view or regenerate

### State Transitions

```swift
// Typical flow
coordinator.startGeneration(with: request)  // input → generating
// Automatic transition when generation completes  // generating → preview
coordinator.applyMealPlan()                 // preview → confirming
// Automatic transition when apply completes       // confirming → completed

// Error handling
coordinator.handleWorkflowError(error)      // Any step → appropriate fallback
coordinator.regenerateMealPlan()            // preview → generating
coordinator.resetWorkflow()                 // Any step → input
```

## Error Handling

### Error Types

The system provides comprehensive error handling through `AIWorkflowError`:

```swift
enum AIWorkflowError {
    case networkError(String)      // Connection issues
    case generationFailed(String)  // AI generation problems
    case previewUnavailable        // No preview data available
    case applyFailed(String)       // Failed to save meal plan
    case invalidRequest(String)    // Invalid user input
    case timeout                   // Request timeout
    case cancelled                 // User cancelled
    case unknown(String)           // Unexpected errors
}
```

### Recovery Actions

Each error type has appropriate recovery actions:

- **Network errors**: Retry with same parameters
- **Generation failures**: Go back to input or regenerate
- **Apply failures**: Retry application or go back to preview
- **Invalid requests**: Return to input for correction

### Custom Error Handling

```swift
coordinator.$showingError
    .sink { isShowing in
        if isShowing {
            // Custom error UI or logging
        }
    }
    .store(in: &cancellables)
```

## Customization Points

### 1. Input Step Customization

Create your own input view implementing the callback pattern:

```swift
struct CustomGenerationInputView: View {
    let onGenerationStart: (AIGenerationRequest) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        // Custom input UI
        // Call onGenerationStart(request) when ready
    }
}
```

### 2. Preview Step Customization

The existing `AIWeeklyPreviewView` can be wrapped with custom bottom bars or additional functionality.

### 3. Loading and Progress

Customize the generation animation:

```swift
struct CustomLoadingView: View {
    let progress: Double
    let stepTitle: String
    
    var body: some View {
        // Custom loading animation
        // Use progress and stepTitle from coordinator
    }
}
```

## Integration with Existing Components

### MealPlanStore Integration

The workflow automatically integrates with `MealPlanStore`:

- Reads AI generation state
- Uses preview meal plan data
- Applies final meal plan to user's week
- Handles cancellation and cleanup

### RecipeStore Integration

- Used for recipe replacement in preview step
- Provides recipe search and filtering
- Supports custom recipe generation

## Testing

### Unit Testing

```swift
class AIWorkflowCoordinatorTests: XCTestCase {
    func testWorkflowFlow() {
        let coordinator = AIWorkflowCoordinator(
            mealPlanStore: MockMealPlanStore(),
            recipeStore: MockRecipeStore()
        )
        
        // Test state transitions
        XCTAssertEqual(coordinator.currentStep, .input)
        
        coordinator.startGeneration(with: mockRequest)
        XCTAssertEqual(coordinator.currentStep, .generating)
        
        // Continue testing...
    }
}
```

### UI Testing

```swift
func testAIWorkflowUI() {
    let app = XCUIApplication()
    app.launch()
    
    app.buttons["Generate AI Meal Plan"].tap()
    
    // Test input step
    XCTAssertTrue(app.textFields["Plan Description"].exists)
    
    // Fill out form and proceed...
}
```

## Performance Considerations

### Memory Management

- Coordinator uses weak references to avoid retain cycles
- Cancellables are properly managed and cleaned up
- Preview data is cleared when not needed

### Network Optimization

- Generation requests include timeout handling
- Failed requests can be retried without losing user input
- Network state is monitored for better error messages

## Best Practices

### 1. State Management

- Always use the coordinator for state changes
- Don't bypass the coordinator's state management
- Handle all state transitions through proper methods

### 2. Error Handling

- Use specific error types rather than generic messages
- Provide clear recovery suggestions to users
- Log errors for debugging but don't overwhelm users

### 3. User Experience

- Show progress indicators during long operations
- Allow cancellation of long-running operations
- Provide clear feedback about what's happening

### 4. Accessibility

- Use proper accessibility labels
- Support VoiceOver navigation
- Ensure keyboard navigation works

## Troubleshooting

### Common Issues

1. **Coordinator not updating**: Ensure `updateDependencies` is called in `onAppear`
2. **State transitions not working**: Check that store states are properly observed
3. **Memory leaks**: Verify weak references and cancellable cleanup

### Debug Information

Enable debug logging:

```swift
// Add to coordinator initialization
coordinator.enableDebugLogging = true
```

This will print detailed state transition information to help diagnose issues.

## Future Enhancements

### Planned Features

1. **Workflow Templates**: Save and reuse common meal plan preferences
2. **Batch Generation**: Generate multiple weeks at once
3. **Smart Suggestions**: Learn from user preferences over time
4. **Offline Mode**: Basic functionality when network is unavailable

### Extension Points

The architecture is designed to be extensible:

- Add new workflow steps by extending `AIWorkflowStep`
- Implement custom error types by extending `AIWorkflowError`
- Create specialized coordinators for different use cases

## Conclusion

The AI Weekly Meal Plan Workflow provides a robust, user-friendly way to generate personalized meal plans. Its modular architecture makes it easy to customize and extend while maintaining a consistent user experience.

For questions or issues, please refer to the source code documentation or create an issue in the project repository.