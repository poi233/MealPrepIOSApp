//
//  ServingAdjustmentSheet.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/22/25.
//

import SwiftUI

struct ServingAdjustmentSheet: View {
    let recipe: Recipe
    @Binding var servingSize: Double
    let onConfirm: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // Predefined serving options
    private let servingOptions: [ServingOption] = [
        ServingOption(value: 0.5, label: "½ serving"),
        ServingOption(value: 1.0, label: "1 serving"),
        ServingOption(value: 1.5, label: "1½ servings"),
        ServingOption(value: 2.0, label: "2 servings"),
        ServingOption(value: 2.5, label: "2½ servings"),
        ServingOption(value: 3.0, label: "3 servings")
    ]
    
    @State private var customServing: String = ""
    @State private var useCustomServing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with recipe info
                recipeHeader
                
                Divider()
                
                // Serving size selection
                servingSizeSelection
                
                Spacer()
                
                // Nutrition preview
                if let nutrition = recipe.nutritionInfo {
                    nutritionPreview(nutrition)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }
                
                // Action buttons
                actionButtons
            }
            .navigationTitle("Adjust Serving")
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
            customServing = String(servingSize)
        }
    }
}

// MARK: - Recipe Header

extension ServingAdjustmentSheet {
    private var recipeHeader: some View {
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
                            .font(.title)
                    )
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Recipe Info
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                Text(recipe.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 16) {
                    Label("\(recipe.totalTime)m", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(recipe.difficulty.rawValue.capitalized, systemImage: "chart.bar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(20)
    }
}

// MARK: - Serving Size Selection

extension ServingAdjustmentSheet {
    private var servingSizeSelection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose Serving Size")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
                .padding(.top, 20)
            
            // Quick selection grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(servingOptions, id: \.value) { option in
                    servingOptionButton(option)
                }
            }
            .padding(.horizontal, 20)
            
            // Custom serving input
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $useCustomServing) {
                    Text("Custom Serving Size")
                        .font(.headline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 20)
                
                if useCustomServing {
                    HStack {
                        TextField("Enter serving size", text: $customServing)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .onChange(of: customServing) { _, newValue in
                                if let value = Double(newValue), value > 0 {
                                    servingSize = value
                                }
                            }
                        
                        Text("servings")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 12)
            
            // Current selection display
            currentSelectionDisplay
                .padding(.horizontal, 20)
        }
    }
    
    private func servingOptionButton(_ option: ServingOption) -> some View {
        Button(action: {
            useCustomServing = false
            servingSize = option.value
        }) {
            VStack(spacing: 8) {
                Text(option.label)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(servingSize == option.value && !useCustomServing ? .white : .primary)
                
                Text(String(format: "%.1fx", option.value))
                    .font(.subheadline)
                    .foregroundColor(servingSize == option.value && !useCustomServing ? .white.opacity(0.8) : .secondary)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(servingSize == option.value && !useCustomServing ? 
                          LinearGradient(colors: [.primaryGreen, .primaryGreen.opacity(0.8)], 
                                       startPoint: .topLeading, endPoint: .bottomTrailing) :
                          LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)], 
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(servingSize == option.value && !useCustomServing ? Color.clear : Color(.systemGray4), lineWidth: 1)
            )
            .scaleEffect(servingSize == option.value && !useCustomServing ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: servingSize)
        }
    }
    
    private var currentSelectionDisplay: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Selected Serving:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: "%.1f servings", servingSize))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            // Stepper for fine-tuning
            Stepper("", value: $servingSize, in: 0.1...10.0, step: 0.1)
                .labelsHidden()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Nutrition Preview

extension ServingAdjustmentSheet {
    private func nutritionPreview(_ nutrition: NutritionInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adjusted Nutrition (per serving)")
                .font(.headline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                let caloriesValue = Int((Double(nutrition.calories ?? "0") ?? 0.0) * servingSize)
                nutritionItem("Calories", value: caloriesValue, unit: "kcal")
                
                let proteinValue = nutrition.protein.flatMap { Double($0) }.map { $0 * servingSize }
                nutritionItem("Protein", value: proteinValue, unit: "g", precision: 1)
                
                let carbsValue = nutrition.carbohydrates.flatMap { Double($0) }.map { $0 * servingSize }
                nutritionItem("Carbs", value: carbsValue, unit: "g", precision: 1)
                
                let fatValue = nutrition.fat.flatMap { Double($0) }.map { $0 * servingSize }
                nutritionItem("Fat", value: fatValue, unit: "g", precision: 1)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func nutritionItem<T: BinaryFloatingPoint>(_ title: String, value: T?, unit: String, precision: Int = 0) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            if let value = value {
                Text("\(String(format: "%.\(precision)f", Double(value)))\(unit)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            } else {
                Text("N/A")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
    }
    
    private func nutritionItem(_ title: String, value: Int, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("\(value)\(unit)")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
    }
}

// MARK: - Action Buttons

extension ServingAdjustmentSheet {
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Divider()
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                
                Button("Add to Meal Plan") {
                    onConfirm()
                    dismiss()
                }
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    LinearGradient(
                        colors: [.primaryGreen, .primaryGreen.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .disabled(servingSize <= 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Supporting Types

struct ServingOption {
    let value: Double
    let label: String
}

// MARK: - Preview

#Preview {
    ServingAdjustmentSheet(
        recipe: Recipe.sampleRecipe,
        servingSize: .constant(1.0),
        onConfirm: {}
    )
}