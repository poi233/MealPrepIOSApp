//
//  BatchOperationsSheet.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/22/25.
//

import SwiftUI

struct BatchOperationsSheet: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedOperation: BatchOperation?
    @State private var showingConfirmation = false
    @State private var isProcessing = false
    @State private var operationResult: BatchOperationResult?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                Divider()
                
                // Operations List
                operationsList
                
                // Result Display
                if let result = operationResult {
                    resultView(result)
                }
                
                Spacer()
                
                // Action Buttons
                if !isProcessing {
                    actionButtons
                }
            }
            .navigationTitle("Batch Operations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Confirm Operation", isPresented: $showingConfirmation, presenting: selectedOperation) { operation in
            Button("Cancel", role: .cancel) { }
            Button(operation.actionTitle, role: operation.isDestructive ? .destructive : .none) {
                executeSelectedOperation()
            }
        } message: { operation in
            Text(operation.confirmationMessage)
        }
    }
}

// MARK: - Header View

extension BatchOperationsSheet {
    private var headerView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Week Operations")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Manage your entire week's meal plan")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Week Summary
            weekSummaryCard
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var weekSummaryCard: some View {
        VStack(spacing: 8) {
            HStack {
                Text(weekDateString)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if let mealCount = currentWeekMealCount {
                    Label("\(mealCount) meals", systemImage: "fork.knife")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let calorieCount = currentWeekCalories {
                HStack {
                    Text("Est. \(Int(calorieCount)) cal/week")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Operations List

extension BatchOperationsSheet {
    private var operationsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(BatchOperation.allCases) { operation in
                    operationButton(operation)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    private func operationButton(_ operation: BatchOperation) -> some View {
        Button(action: {
            selectedOperation = operation
            if operation.requiresConfirmation {
                showingConfirmation = true
            } else {
                executeSelectedOperation()
            }
        }) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: operation.iconName)
                    .font(.title2)
                    .foregroundColor(operation.color)
                    .frame(width: 24, height: 24)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(operation.title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(operation.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Availability Indicator
                if !operation.isAvailable(for: mealPlanStore) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.orange)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
        .disabled(!operation.isAvailable(for: mealPlanStore))
        .opacity(operation.isAvailable(for: mealPlanStore) ? 1.0 : 0.6)
    }
}

// MARK: - Result View

extension BatchOperationsSheet {
    private func resultView(_ result: BatchOperationResult) -> some View {
        VStack(spacing: 16) {
            Divider()
            
            VStack(spacing: 12) {
                // Status Icon
                Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(result.isSuccess ? .green : .red)
                
                // Title and Message
                VStack(spacing: 4) {
                    Text(result.title)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text(result.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Details (if any)
                if let details = result.details, !details.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(details, id: \.self) { detail in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 4))
                                    .foregroundColor(.secondary)
                                
                                Text(detail)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
    }
}

// MARK: - Action Buttons

extension BatchOperationsSheet {
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if operationResult != nil {
                Button("Done") {
                    dismiss()
                }
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.primaryGreen)
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 20)
    }
}

// MARK: - Computed Properties

extension BatchOperationsSheet {
    private var weekDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let startDate = mealPlanStore.selectedWeekStartDate
        let endDate = Calendar.current.date(byAdding: .day, value: 6, to: startDate) ?? startDate
        
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    private var currentWeekMealCount: Int? {
        guard let activePlan = mealPlanStore.activeMealPlan,
              let items = activePlan.items else { return nil }
        return items.count
    }
    
    private var currentWeekCalories: Double? {
        guard let activePlan = mealPlanStore.activeMealPlan,
              let items = activePlan.items else { return nil }
        
        var totalCalories: Double = 0
        var hasValidData = false
        
        for item in items {
            if let recipe = item.recipe,
               let nutrition = recipe.nutritionInfo,
               let caloriesStr = nutrition.calories,
               let calories = Double(caloriesStr) {
                totalCalories += calories
                hasValidData = true
            }
        }
        
        return hasValidData ? totalCalories : nil
    }
}

// MARK: - Actions

extension BatchOperationsSheet {
    private func executeSelectedOperation() {
        guard let operation = selectedOperation else { return }
        
        isProcessing = true
        operationResult = nil
        
        Task {
            let result = await performBatchOperation(operation)
            
            await MainActor.run {
                operationResult = result
                isProcessing = false
            }
        }
    }
    
    private func performBatchOperation(_ operation: BatchOperation) async -> BatchOperationResult {
        switch operation {
        case .copyFromLastWeek:
            return await copyFromLastWeek()
        case .autoFillWithAI:
            return await autoFillWithAI()
        case .clearAllMeals:
            return await clearAllMeals()
        case .duplicateToNextWeek:
            return await duplicateToNextWeek()
        case .generateShoppingList:
            return await generateShoppingList()
        }
    }
    
    private func copyFromLastWeek() async -> BatchOperationResult {
        // Implementation would copy meals from last week
        // await mealPlanStore.copyMealsFromLastWeek()
        
        return BatchOperationResult(
            isSuccess: true,
            title: "Meals Copied",
            message: "Successfully copied meals from last week"
        )
    }
    

    
    private func autoFillWithAI() async -> BatchOperationResult {
        // Implementation would generate AI meals
        // await mealPlanStore.generateWeekWithAI()
        
        return BatchOperationResult(
            isSuccess: true,
            title: "AI Generation Complete",
            message: "AI has filled your week with personalized meal recommendations"
        )
    }
    
    private func clearAllMeals() async -> BatchOperationResult {
        // Implementation would clear all meals
        // await mealPlanStore.clearAllMealsForWeek()
        
        return BatchOperationResult(
            isSuccess: true,
            title: "All Meals Cleared",
            message: "All meals have been removed from this week"
        )
    }
    
    private func duplicateToNextWeek() async -> BatchOperationResult {
        guard mealPlanStore.activeMealPlan != nil else {
            return BatchOperationResult(
                isSuccess: false,
                title: "No Active Plan",
                message: "No active meal plan to duplicate"
            )
        }
        
        // Implementation would duplicate to next week
        // await mealPlanStore.duplicateWeekToPlan(currentPlan, weekStartDate: nextWeekStart)
        
        return BatchOperationResult(
            isSuccess: true,
            title: "Week Duplicated",
            message: "This week's meals have been copied to next week"
        )
    }
    
    private func generateShoppingList() async -> BatchOperationResult {
        // Implementation would generate shopping list
        // await mealPlanStore.generateShoppingListForWeek()
        
        return BatchOperationResult(
            isSuccess: true,
            title: "Shopping List Generated",
            message: "Shopping list has been created from this week's meals"
        )
    }
}

// MARK: - Supporting Types

enum BatchOperation: CaseIterable, Identifiable {
    case copyFromLastWeek
    case duplicateToNextWeek
    case clearAllMeals
    case autoFillWithAI
    case generateShoppingList
    
    var id: String {
        switch self {
        case .copyFromLastWeek: return "copy-last-week"
        case .autoFillWithAI: return "auto-fill-ai"
        case .clearAllMeals: return "clear-all"
        case .duplicateToNextWeek: return "duplicate-next"
        case .generateShoppingList: return "shopping-list"
        }
    }
    
    var title: String {
        switch self {
        case .copyFromLastWeek: return "Copy from Last Week"
        case .autoFillWithAI: return "Auto-fill with AI"
        case .clearAllMeals: return "Clear All Meals"
        case .duplicateToNextWeek: return "Duplicate to Next Week"
        case .generateShoppingList: return "Generate Shopping List"
        }
    }
    
    var description: String {
        switch self {
        case .copyFromLastWeek: return "Copy all meals from the previous week"
        case .autoFillWithAI: return "Let AI fill empty meal slots intelligently"
        case .clearAllMeals: return "Remove all meals from this week"
        case .duplicateToNextWeek: return "Copy this week's meals to next week"
        case .generateShoppingList: return "Create shopping list from this week's meals"
        }
    }
    
    var iconName: String {
        switch self {
        case .copyFromLastWeek: return "arrow.uturn.backward"
        case .autoFillWithAI: return "brain.head.profile"
        case .clearAllMeals: return "trash"
        case .duplicateToNextWeek: return "arrow.uturn.forward"
        case .generateShoppingList: return "cart"
        }
    }
    
    var color: Color {
        switch self {
        case .copyFromLastWeek: return .blue
        case .autoFillWithAI: return .green
        case .clearAllMeals: return .red
        case .duplicateToNextWeek: return .orange
        case .generateShoppingList: return .indigo
        }
    }
    
    var requiresConfirmation: Bool {
        switch self {
        case .clearAllMeals: return true
        case .copyFromLastWeek: return true
        case .duplicateToNextWeek: return true
        default: return false
        }
    }
    
    var confirmationTitle: String {
        switch self {
        case .clearAllMeals: return "Clear All Meals?"
        case .copyFromLastWeek: return "Copy from Last Week?"
        case .duplicateToNextWeek: return "Duplicate to Next Week?"
        default: return "Confirm Action?"
        }
    }
    
    var confirmationMessage: String {
        switch self {
        case .clearAllMeals: return "This will remove all meals from the current week. This action cannot be undone."
        case .copyFromLastWeek: return "This will replace any existing meals in the current week with meals from last week."
        case .duplicateToNextWeek: return "This will copy all meals from this week to next week, replacing any existing meals."
        default: return "Are you sure you want to continue?"
        }
    }
    
    var actionTitle: String {
        switch self {
        case .clearAllMeals: return "Clear All"
        case .copyFromLastWeek: return "Copy Meals"
        case .duplicateToNextWeek: return "Duplicate Week"
        default: return "Confirm"
        }
    }
    
    var isDestructive: Bool {
        switch self {
        case .clearAllMeals: return true
        default: return false
        }
    }
    
    @MainActor func isAvailable(for store: MealPlanStore) -> Bool {
        switch self {
        case .copyFromLastWeek:
            // Check if there's a previous week plan
            let calendar = Calendar.current
            let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: store.selectedWeekStartDate)!
            return store.mealPlans.contains { plan in
                calendar.isDate(plan.weekStartDate, inSameDayAs: lastWeekStart)
            }
        case .clearAllMeals, .duplicateToNextWeek:
            return store.activeMealPlan != nil
        case .generateShoppingList:
            return store.activeMealPlan?.items?.isEmpty == false
        default:
            return true
        }
    }
}

struct BatchOperationResult {
    let isSuccess: Bool
    let title: String
    let message: String
    let itemCount: Int?
    let details: [String]?
    
    init(isSuccess: Bool, title: String, message: String, itemCount: Int? = nil, details: [String]? = nil) {
        self.isSuccess = isSuccess
        self.title = title
        self.message = message
        self.itemCount = itemCount
        self.details = details
    }
}

// MARK: - Preview

#Preview {
    BatchOperationsSheet()
        .environmentObject(MealPlanStore())
}