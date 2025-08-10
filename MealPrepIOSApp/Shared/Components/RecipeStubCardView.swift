//
//  RecipeStubCardView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 8/2/25.
//

import SwiftUI
import UIKit

/// A high-performance card view for displaying RecipeStub information with Apply to Plan action
struct RecipeStubCardView: View {
    let recipeStub: RecipeStub
    let mealType: MealType
    let dayOfWeek: Int
    let date: Date

    @EnvironmentObject var mealPlanStore: MealPlanStore
    @EnvironmentObject var recipeStore: RecipeStore
    @State private var isApplying = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    // MARK: - Performance Optimized Properties

    // Cache expensive computations to avoid recreating on every body call
    private let mealColor: Color
    private let buttonGradient: LinearGradient
    private let disabledBackground: Color
    private let shadowColor: Color
    private let shadowRadius: CGFloat
    private let shadowOffset: CGSize

    // Cached formatted strings to avoid repeated string interpolation
    private let caloriesText: String
    private let prepTimeText: String
    private let cuisineDisplay: String

    // Initialize cached properties once in init
    init(recipeStub: RecipeStub, mealType: MealType, dayOfWeek: Int, date: Date) {
        self.recipeStub = recipeStub
        self.mealType = mealType
        self.dayOfWeek = dayOfWeek
        self.date = date

        // Cache meal color to avoid switch statement on every redraw
        switch mealType {
        case .breakfast: self.mealColor = .orange
        case .lunch: self.mealColor = .yellow
        case .dinner: self.mealColor = .purple
        }

        // Pre-create expensive gradient (avoid recreating LinearGradient repeatedly)
        self.buttonGradient = LinearGradient(
            colors: [.primaryGreen, .primaryGreen.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Pre-create disabled state color
        self.disabledBackground = .gray.opacity(0.6)

        // Pre-create shadow configuration (expensive shadow calculations)
        self.shadowColor = .black.opacity(0.08)
        self.shadowRadius = 6
        self.shadowOffset = CGSize(width: 0, height: 3)

        // Cache formatted strings to avoid string interpolation on every render
        self.caloriesText = "\(recipeStub.estimatedCalories) 卡路里"
        self.prepTimeText = "\(recipeStub.estimatedPrepTime)分钟"
        self.cuisineDisplay = recipeStub.cuisineDisplay
    }

    @ViewBuilder
    private var optimizedButtonBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isApplying ? AnyShapeStyle(disabledBackground) : AnyShapeStyle(buttonGradient))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Recipe stub header - optimized with cached colors
            headerSection

            // Conditional description - optimize conditional rendering
            descriptionSection

            // Nutrition info row - use ViewBuilder for better performance
            nutritionInfoSection

            // Tags section - lazy loading for better scroll performance
            tagsSection

            // Apply to Plan button - optimized button rendering
            actionButton
        }
        .padding(16)
        .background(optimizedCardBackground)
        .alert("应用失败", isPresented: $showingErrorAlert) {
            Button("确定") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Optimized View Components

    @ViewBuilder
    private var headerSection: some View {
        HStack(spacing: 12) {
            // Recipe stub icon - cached colors reduce recomputation
            RoundedRectangle(cornerRadius: 8)
                .fill(mealColor.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: recipeStub.isAIGenerated ? "sparkles" : "fork.knife")
                        .font(.title2)
                        .foregroundColor(mealColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                // Recipe name
                Text(recipeStub.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                // Cuisine and status - optimize conditional rendering
                cuisineStatusRow
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var cuisineStatusRow: some View {
        HStack(spacing: 8) {
            Text(cuisineDisplay)
                .font(.caption)
                .foregroundColor(.secondary)

            // Conditional AI badge - only create when needed
            if recipeStub.isAIGenerated {
                aiBadge
            }
        }
    }

    // Separate AI badge to avoid recreating when not needed
    private var aiBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.caption2)
            Text("AI生成")
                .font(.caption2)
        }
        .foregroundColor(.purple)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.purple.opacity(0.1))
        )
    }

    @ViewBuilder
    private var descriptionSection: some View {
        if !recipeStub.description.isEmpty {
            Text(recipeStub.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
    }

    private var nutritionInfoSection: some View {
        HStack(spacing: 16) {
            // Calories info - using cached string
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text(caloriesText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Prep time info - using cached string
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text(prepTimeText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        if !recipeStub.tagsDisplay.isEmpty {
            // Use LazyHStack for better performance with many tags
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 6) {
                    ForEach(recipeStub.tagsDisplay, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(mealColor.opacity(0.1))
                            )
                            .foregroundColor(mealColor)
                    }
                }
                .padding(.horizontal, 1) // Prevent clipping
            }
        }
    }

    private var actionButton: some View {
        Button(action: {
            Task {
                await applyToPlan()
            }
        }) {
            HStack(spacing: 8) {
                // Optimize icon rendering based on state
                buttonIcon

                Text(isApplying ? "添加中..." : "添加到计划")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(optimizedButtonBackground)
        }
        .disabled(isApplying)
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var buttonIcon: some View {
        if isApplying {
            ProgressView()
                .scaleEffect(0.8)
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 16, weight: .medium))
        }
    }

    private var optimizedCardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground))
            .shadow(color: shadowColor, radius: shadowRadius, x: shadowOffset.width, y: shadowOffset.height)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(mealColor.opacity(0.2), lineWidth: 1)
            )
    }

    // MARK: - Helper Methods

    private func applyToPlan() async {
        guard !isApplying else { return }

        isApplying = true

        do {
            print("🔄 [RecipeStubCardView] Applying recipe stub to plan: \(recipeStub.name)")

            // Call the RecipeStore's applyMeal function
            let success = await recipeStore.applyMealToPlan(
                recipeStub: recipeStub,
                mealPlanId: mealPlanStore.activeMealPlan?.id,
                dayOfWeek: dayOfWeek,
                mealType: mealType.rawValue,
                servingSize: 1.0,
                saveToAccount: true
            )

            if success {
                print("✅ [RecipeStubCardView] Successfully applied meal to plan")

                // Refresh the meal plan to show the new recipe
                await mealPlanStore.refreshMealPlans()

                // Show success feedback (optional - could add haptic feedback)
                if #available(iOS 17.0, *) {
                    // Modern haptic feedback
                } else {
                    // Fallback haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
            } else {
                throw RecipeStoreError.applyMealFailed("Failed to apply meal to plan")
            }

        } catch {
            print("❌ [RecipeStubCardView] Failed to apply meal: \(error)")
            errorMessage = "无法添加到计划: \(error.localizedDescription)"
            showingErrorAlert = true
        }

        isApplying = false
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        RecipeStubCardView(
            recipeStub: RecipeStub.sampleStub,
            mealType: .lunch,
            dayOfWeek: 1,
            date: Date()
        )

        RecipeStubCardView(
            recipeStub: RecipeStub.sampleExistingStub,
            mealType: .dinner,
            dayOfWeek: 1,
            date: Date()
        )
    }
    .padding()
    .background(Color(.systemGray6))

    .environmentObject(MealPlanStore())
    .environmentObject(RecipeStore())
}