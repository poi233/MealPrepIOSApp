//
//  MealActionSheet.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/22/25.
//

import SwiftUI

struct MealActionSheet: View {
    let mealPlanItem: MealPlanItem
    let recipe: Recipe
    
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @EnvironmentObject var recipeStore: RecipeStore
    
    @State private var showingRecipeDetail = false
    @State private var showingSwapMeal = false
    @State private var showingServingAdjustment = false
    @State private var showingMoveMeal = false
    @State private var showingDeleteConfirmation = false
    @State private var newServingSize: Double = 1.0
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Sheet Header with meal info
            sheetHeader
            
            Divider()
            
            // Action options
            ScrollView {
                VStack(spacing: 0) {
                    actionButton(
                        title: "View Recipe",
                        subtitle: "See full recipe details",
                        icon: "book.pages",
                        color: .blue,
                        action: {
                            showingRecipeDetail = true
                        }
                    )
                    
                    actionButton(
                        title: "Swap Meal",
                        subtitle: "Replace with another recipe",
                        icon: "arrow.triangle.swap",
                        color: .orange,
                        action: {
                            showingSwapMeal = true
                        }
                    )
                    
                    actionButton(
                        title: "Adjust Serving",
                        subtitle: "Change portion size",
                        icon: "slider.horizontal.3",
                        color: .green,
                        action: {
                            newServingSize = 1.0  // Default serving size
                            showingServingAdjustment = true
                        }
                    )
                    
                    actionButton(
                        title: "Move to Another Meal",
                        subtitle: "Change day or meal type",
                        icon: "arrow.up.arrow.down",
                        color: .purple,
                        action: {
                            showingMoveMeal = true
                        }
                    )
                    
                    actionButton(
                        title: "Duplicate",
                        subtitle: "Copy to another meal slot",
                        icon: "doc.on.doc",
                        color: .indigo,
                        action: {
                            duplicateMeal()
                        }
                    )
                    
                    actionButton(
                        title: "Remove",
                        subtitle: "Delete this meal",
                        icon: "trash",
                        color: .red,
                        action: {
                            showingDeleteConfirmation = true
                        }
                    )
                }
                .padding(.vertical, 8)
            }
        }
        .sheet(isPresented: $showingRecipeDetail) {
            RecipeDetailView(recipe: recipe)
        }
        .sheet(isPresented: $showingSwapMeal) {
            MealSelectionBottomSheet(
                dayOfWeek: mealPlanItem.dayOfWeek,
                mealType: MealType(rawValue: mealPlanItem.mealType) ?? .breakfast,
                date: dateForDayOfWeek(mealPlanItem.dayOfWeek)
            )
        }
        .sheet(isPresented: $showingServingAdjustment) {
            ServingAdjustmentSheet(
                recipe: recipe,
                servingSize: $newServingSize,
                onConfirm: adjustServing
            )
        }
        .sheet(isPresented: $showingMoveMeal) {
            MoveMealSheet(
                mealPlanItem: mealPlanItem,
                recipe: recipe
            )
        }
        .alert("Remove Meal", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                removeMeal()
            }
        } message: {
            Text("Are you sure you want to remove this meal from your plan?")
        }
    }
}

// MARK: - Header View

extension MealActionSheet {
    private var sheetHeader: some View {
        VStack(spacing: 16) {
            // Drag Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 6)
                .padding(.top, 8)
            
            // Meal Info
            HStack(spacing: 16) {
                // Recipe Image
                AsyncImage(url: URL(string: recipe.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.1))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        )
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Meal Details
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(2)
                    
                    Text("\(mealPlanItem.mealType.capitalized) • \(dayString)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let nutrition = recipe.nutritionInfo,
                       let caloriesStr = nutrition.calories,
                       let calories = Int(caloriesStr) {
                        HStack {
                            Label("\(calories) cal", systemImage: "flame")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            if recipe.totalTime > 0 {
                                Label("\(recipe.totalTime)m", systemImage: "clock")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 16)
    }
    
    private var dayString: String {
        let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return days[safe: mealPlanItem.dayOfWeek] ?? "Unknown"
    }
}

// MARK: - Action Button

extension MealActionSheet {
    private func actionButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary.opacity(0.6))
                    .font(.caption)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Actions

extension MealActionSheet {
    private func adjustServing() {
        Task {
            await mealPlanStore.updateMealServingSize(
                mealPlanItem: mealPlanItem,
                newServingSize: newServingSize
            )
            dismiss()
        }
    }
    
    private func duplicateMeal() {
        // For simplicity, we'll duplicate to the same day, next meal type
        let nextMealType: MealType = {
            switch MealType(rawValue: mealPlanItem.mealType) {
            case .breakfast: return .lunch
            case .lunch: return .dinner
            case .dinner: return .snack
            case .snack: return .breakfast
            case .none: return .breakfast
            }
        }()
        
        Task {
            await mealPlanStore.duplicateMeal(
                mealPlanItem: mealPlanItem,
                toDayOfWeek: mealPlanItem.dayOfWeek,
                toMealType: nextMealType
            )
            dismiss()
        }
    }
    
    private func removeMeal() {
        Task {
            await mealPlanStore.removeMealFromPlan(mealPlanItem: mealPlanItem)
            dismiss()
        }
    }
    
    private func dateForDayOfWeek(_ dayOfWeek: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday == 1) ? 6 : weekday - 2 // Convert to Monday = 0
        let mondayThisWeek = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        return calendar.date(byAdding: .day, value: dayOfWeek, to: mondayThisWeek)!
    }
}

// MARK: - Move Meal Sheet

struct MoveMealSheet: View {
    let mealPlanItem: MealPlanItem
    let recipe: Recipe
    
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDayOfWeek: Int = 0
    @State private var selectedMealType: MealType = .breakfast
    @State private var isDuplicating = false
    
    private let weekDays = [
        "Monday", "Tuesday", "Wednesday", "Thursday",
        "Friday", "Saturday", "Sunday"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Current meal info
                currentMealInfo
                
                Divider()
                
                // Day selection
                daySelection
                
                // Meal type selection
                mealTypeSelection
                
                // Duplicate option
                duplicateOption
                
                Spacer()
                
                // Move button
                moveButton
            }
            .padding(.horizontal, 20)
            .navigationTitle("Move Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            selectedDayOfWeek = mealPlanItem.dayOfWeek
            selectedMealType = MealType(rawValue: mealPlanItem.mealType) ?? .breakfast
        }
    }
    
    private var currentMealInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Moving:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text(recipe.name)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            Text("From \(mealPlanItem.mealType.capitalized) on \(weekDays[safe: mealPlanItem.dayOfWeek] ?? "Unknown")")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var daySelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Day")
                .font(.headline)
                .fontWeight(.medium)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<weekDays.count, id: \.self) { dayIndex in
                        dayButton(for: dayIndex)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func dayButton(for dayIndex: Int) -> some View {
        Button(action: {
            selectedDayOfWeek = dayIndex
        }) {
            VStack(spacing: 4) {
                Text(String(weekDays[dayIndex].prefix(3)))
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("\(dayIndex + 1)")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .foregroundColor(selectedDayOfWeek == dayIndex ? .white : .primary)
            .frame(width: 50, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedDayOfWeek == dayIndex ? Color.accentColor : Color(.systemGray6))
            )
        }
    }
    
    private var mealTypeSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Meal Type")
                .font(.headline)
                .fontWeight(.medium)
            
            VStack(spacing: 8) {
                ForEach(MealType.allCases, id: \.self) { mealType in
                    mealTypeButton(for: mealType)
                }
            }
        }
    }
    
    private func mealTypeButton(for mealType: MealType) -> some View {
        Button(action: {
            selectedMealType = mealType
        }) {
            HStack {
                Text(mealType.rawValue.capitalized)
                    .font(.body)
                    .fontWeight(.medium)
                
                Spacer()
                
                if selectedMealType == mealType {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .foregroundColor(selectedMealType == mealType ? .accentColor : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedMealType == mealType ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            )
        }
    }
    
    private var duplicateOption: some View {
        Toggle(isOn: $isDuplicating) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Keep Original")
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("Duplicate instead of moving")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .toggleStyle(SwitchToggleStyle())
    }
    
    private var moveButton: some View {
        Button(action: isDuplicating ? duplicateMeal : moveMeal) {
            Text(isDuplicating ? "Duplicate Meal" : "Move Meal")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    LinearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
        }
        .disabled(selectedDayOfWeek == mealPlanItem.dayOfWeek && 
                 selectedMealType.rawValue == mealPlanItem.mealType && 
                 !isDuplicating)
    }
    
    private func moveMeal() {
        Task {
            await mealPlanStore.moveMeal(
                from: mealPlanItem,
                toDayOfWeek: selectedDayOfWeek,
                toMealType: selectedMealType
            )
            dismiss()
        }
    }
    
    private func duplicateMeal() {
        Task {
            await mealPlanStore.duplicateMeal(
                mealPlanItem: mealPlanItem,
                toDayOfWeek: selectedDayOfWeek,
                toMealType: selectedMealType
            )
            dismiss()
        }
    }
}

// MARK: - Array Extension for Safe Access

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview {
    MealActionSheet(
        mealPlanItem: MealPlanItem.sampleItem,
        recipe: Recipe.sampleRecipe
    )
    .environmentObject(MealPlanStore())
    .environmentObject(RecipeStore())
}