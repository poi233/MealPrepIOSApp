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

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView

                Divider()

                // Operations List
                operationsList

                Spacer()
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

// MARK: - Computed Properties

extension BatchOperationsSheet {
    private var weekDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let startDate = Date().startOfWeek()
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

        Task {
            let result = await performBatchOperation(operation)

            await MainActor.run {
                isProcessing = false
                // 直接关闭sheet而不显示结果
                dismiss()
            }
        }
    }

    private func performBatchOperation(_ operation: BatchOperation) async -> BatchOperationResult {
        switch operation {
        case .copyFromLastWeek:
            return await copyFromLastWeek()
        case .clearAllMeals:
            return await clearAllMeals()
        case .duplicateToNextWeek:
            return await duplicateToNextWeek()
        }
    }

    private func copyFromLastWeek() async -> BatchOperationResult {
        return await mealPlanStore.copyMealsFromLastWeek()
    }



    private func clearAllMeals() async -> BatchOperationResult {
        return await mealPlanStore.clearAllMealsForWeek()
    }

    private func duplicateToNextWeek() async -> BatchOperationResult {
        return await mealPlanStore.duplicateWeekToNextWeek()
    }
}

// MARK: - Supporting Types
// BatchOperation and BatchOperationResult are now defined in BatchOperationModels.swift

// MARK: - Preview

#Preview {
    BatchOperationsSheet()
        .environmentObject(MealPlanStore())
}