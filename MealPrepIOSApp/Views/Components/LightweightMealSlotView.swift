//
//  LightweightMealSlotView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 8/2/25.
//

import SwiftUI

/// A meal slot view that displays RecipeStub cards for lightweight meal plan suggestions
struct LightweightMealSlotView: View {
    let title: String
    let recipeStubs: [RecipeStub]
    let mealType: MealType
    let dayOfWeek: Int
    let date: Date
    
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @State private var showingMealSelection = false
    
    private var mealIcon: String {
        switch mealType {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon"
        }
    }
    
    private var mealColor: Color {
        switch mealType {
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .purple
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Meal type header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: mealIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(mealColor)
                    
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    // AI suggestions badge
                    if !recipeStubs.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text("AI推荐")
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
                }
                
                Spacer()
                
                // Add button for traditional meal selection
                Button(action: {
                    showingMealSelection = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.primaryGreen)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 32, height: 32)
            }
            
            // RecipeStub cards or empty state
            if recipeStubs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife.circle")
                        .font(.title2)
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text("暂无AI推荐")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                    
                    Text("点击 + 手动添加菜谱")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(recipeStubs, id: \.name) { recipeStub in
                        RecipeStubCardView(
                            recipeStub: recipeStub,
                            mealType: mealType,
                            dayOfWeek: dayOfWeek,
                            date: date
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.5))
        )
        .sheet(isPresented: $showingMealSelection) {
            MealSelectionBottomSheet(
                dayOfWeek: dayOfWeek,
                mealType: mealType,
                date: date
            )
            .environmentObject(mealPlanStore)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        LightweightMealSlotView(
            title: "午餐",
            recipeStubs: [RecipeStub.sampleStub, RecipeStub.sampleExistingStub],
            mealType: .lunch,
            dayOfWeek: 1,
            date: Date()
        )
    }
    .padding()
    .background(Color(.systemGray6))
    .environmentObject(MealPlanStore())
}