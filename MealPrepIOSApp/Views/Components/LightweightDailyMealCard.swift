//
//  LightweightDailyMealCard.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 8/2/25.
//

import SwiftUI

/// A daily meal card that displays RecipeStub cards for lightweight meal plan suggestions
struct LightweightDailyMealCard: View {
    let lightweightDailyMeal: LightweightDailyMeal
    let dayOfWeek: Int
    let date: Date

    @EnvironmentObject var mealPlanStore: MealPlanStore
    @State private var isExpanded = false

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var totalRecipeStubs: Int {
        lightweightDailyMeal.breakfast.count +
        lightweightDailyMeal.lunch.count +
        lightweightDailyMeal.dinner.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day header
            dayHeader

            if isExpanded {
                // Meal slots
                VStack(spacing: 12) {
                    if !lightweightDailyMeal.breakfast.isEmpty {
                        LightweightMealSlotView(
                            title: "早餐",
                            recipeStubs: lightweightDailyMeal.breakfast,
                            mealType: .breakfast,
                            dayOfWeek: dayOfWeek,
                            date: date
                        )
                    }

                    if !lightweightDailyMeal.lunch.isEmpty {
                        LightweightMealSlotView(
                            title: "午餐",
                            recipeStubs: lightweightDailyMeal.lunch,
                            mealType: .lunch,
                            dayOfWeek: dayOfWeek,
                            date: date
                        )
                    }

                    if !lightweightDailyMeal.dinner.isEmpty {
                        LightweightMealSlotView(
                            title: "晚餐",
                            recipeStubs: lightweightDailyMeal.dinner,
                            mealType: .dinner,
                            dayOfWeek: dayOfWeek,
                            date: date
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
    }

    private var dayHeader: some View {
        HStack {
            // Day circle
            VStack(spacing: 2) {
                Text(dayName.prefix(3))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Text(dayNumber)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .frame(width: 50, height: 50)
            .background(
                Circle()
                    .fill(Color(.systemGray6))
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(dayName)
                    .font(.headline)
                    .fontWeight(.semibold)

                if totalRecipeStubs > 0 {
                    Text("\(totalRecipeStubs) 个建议菜谱")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("暂无建议")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Expand/collapse indicator
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
}

// MARK: - Preview

#if DEBUG
struct LightweightDailyMealCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            LightweightDailyMealCard(
                lightweightDailyMeal: LightweightDailyMeal.sampleDay,
                dayOfWeek: 1,
                date: Date()
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .previewLayout(.sizeThatFits)
        .environmentObject(MealPlanStore())
        .environmentObject(RecipeStore())
    }
}
#endif