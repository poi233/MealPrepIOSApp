//
//  AIWeeklyGenerationViewWithCallbacks.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/28/25.
//

import SwiftUI

/// Enhanced version of AIWeeklyGenerationView with workflow callback support
struct AIWeeklyGenerationViewWithCallbacks: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore
    
    // MARK: - Workflow Integration
    let onGenerationStart: (AIGenerationRequest) -> Void
    let onCancel: () -> Void
    
    // MARK: - Step Management
    @State private var currentStep = 1
    private let totalSteps = 4
    
    // MARK: - Form Data
    @State private var planDescription = ""
    @State private var selectedDietType: DietType?
    @State private var selectedAllergies: Set<String> = []
    @State private var calorieTarget: Double = 2000
    // weekStartDate removed - dates managed by WeeklyMealGrid
    
    // MARK: - UI State
    @State private var showingCalorieSlider = false
    
    // MARK: - Data
    private let commonAllergies = ["Nuts", "Shellfish", "Dairy", "Eggs", "Soy", "Gluten", "Fish", "Sesame"]
    private let commonDietTypes = DietType.allCases
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Progress Header
                progressHeader
                
                // Current Step Content
                currentStepView
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .bottom) {
            bottomActionBar
        }
        .disabled(mealPlanStore.isGenerating)
        .onAppear {
            setupInitialValues()
        }
    }
    
    // MARK: - Progress Header
    private var progressHeader: some View {
        VStack(spacing: 16) {
            // Progress Bar
            ProgressView(value: Double(currentStep), total: Double(totalSteps))
                .progressViewStyle(LinearProgressViewStyle(tint: .primaryGreen))
                .scaleEffect(y: 2)
            
            // Step Indicator
            HStack {
                ForEach(1...totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.primaryGreen : Color(.systemGray4))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.primaryGreen, lineWidth: step == currentStep ? 2 : 0)
                                .frame(width: 16, height: 16)
                        )
                    
                    if step < totalSteps {
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Step Title
            Text(stepTitle(for: currentStep))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .greenThemeCard()
    }
    
    // MARK: - Current Step View
    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case 1:
            step1_Description
        case 2:
            step2_DietPreferences
        case 3:
            step3_AllergiesAndRestrictions
        case 4:
            step4_FinalSettings
        default:
            EmptyView()
        }
    }
    
    // MARK: - Step 1: Description
    private var step1_Description: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Tell us about your ideal weekly meal plan")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Describe what you're looking for in simple terms. The AI will use this to create personalized meals for your entire week.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(nil)
            
            TextField("e.g., Healthy family meals with variety, quick weeknight dinners...", text: $planDescription, axis: .vertical)
                .textFieldStyle(GreenTextFieldStyle())
                .lineLimit(4...8)
                .textInputAutocapitalization(.sentences)
            
            // Quick suggestions
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick suggestions:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                LazyVStack(spacing: 8) {
                    ForEach(descriptionSuggestions, id: \.self) { suggestion in
                        Button(action: {
                            planDescription = suggestion
                        }) {
                            HStack {
                                Text(suggestion)
                                    .font(.callout)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .font(.caption)
                                    .foregroundColor(.primaryGreen)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .greenThemeCard()
    }
    
    // MARK: - Step 2: Diet Preferences
    private var step2_DietPreferences: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Any specific diet you follow?")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Choose a diet type if you have specific preferences, or skip this step.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Diet Type Selection
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                // "No specific diet" option
                dietOptionCard(
                    title: "No Specific Diet",
                    description: "I eat everything",
                    isSelected: selectedDietType == nil
                ) {
                    selectedDietType = nil
                }
                
                // Diet type options
                ForEach(commonDietTypes, id: \.self) { dietType in
                    dietOptionCard(
                        title: dietType.displayName,
                        description: dietTypeDescription(dietType),
                        isSelected: selectedDietType == dietType
                    ) {
                        selectedDietType = dietType
                    }
                }
            }
        }
        .greenThemeCard()
    }
    
    // MARK: - Step 3: Allergies and Restrictions
    private var step3_AllergiesAndRestrictions: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Any allergies or foods to avoid?")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Select any allergies or foods you'd like to avoid in your meal plan.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Allergy Selection
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(commonAllergies, id: \.self) { allergy in
                    allergyCard(
                        title: allergy,
                        isSelected: selectedAllergies.contains(allergy)
                    ) {
                        if selectedAllergies.contains(allergy) {
                            selectedAllergies.remove(allergy)
                        } else {
                            selectedAllergies.insert(allergy)
                        }
                    }
                }
            }
            
            if !selectedAllergies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected restrictions:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    FlowLayout(Array(selectedAllergies)) { allergy in
                        HStack(spacing: 4) {
                            Text(allergy)
                                .font(.caption)
                            Button(action: {
                                selectedAllergies.remove(allergy)
                            }) {
                                Image(systemName: "xmark")
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.error.opacity(0.1))
                        .foregroundColor(.error)
                        .cornerRadius(6)
                    }
                }
                .padding(.top, 8)
            }
        }
        .greenThemeCard()
    }
    
    // MARK: - Step 4: Final Settings
    private var step4_FinalSettings: some View {
        VStack(spacing: 20) {
            // Calorie Target
            VStack(alignment: .leading, spacing: 16) {
                Text("Daily calorie target")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    HStack {
                        Text("\(Int(calorieTarget)) calories/day")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryGreen)
                        
                        Spacer()
                        
                        Button(action: {
                            showingCalorieSlider.toggle()
                        }) {
                            Text(showingCalorieSlider ? "Done" : "Adjust")
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                        .outlineGreenButton()
                    }
                    
                    if showingCalorieSlider {
                        VStack(spacing: 8) {
                            Slider(value: $calorieTarget, in: 1200...3500, step: 50) {
                                Text("Calories")
                            }
                            .tint(.primaryGreen)
                            
                            HStack {
                                Text("1,200")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("3,500")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .greenThemeCard()
            
            // Week Start Date
            VStack(alignment: .leading, spacing: 16) {
                Text("Week starting date")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Using current week dates")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .greenThemeCard()
            
            // Summary Card
            summaryCard
        }
    }
    
    // MARK: - Summary Card
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Summary")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                if !planDescription.isEmpty {
                    summaryRow(title: "Plan", value: planDescription)
                }
                
                if let dietType = selectedDietType {
                    summaryRow(title: "Diet", value: dietType.displayName)
                } else {
                    summaryRow(title: "Diet", value: "No restrictions")
                }
                
                if !selectedAllergies.isEmpty {
                    summaryRow(title: "Avoid", value: Array(selectedAllergies).joined(separator: ", "))
                } else {
                    summaryRow(title: "Avoid", value: "No restrictions")
                }
                
                summaryRow(title: "Calories", value: "\(Int(calorieTarget))/day")
                summaryRow(title: "Week", value: "Current Week")
            }
        }
        .greenThemeCard()
    }
    
    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 16) {
                if currentStep > 1 {
                    Button("Previous") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep -= 1
                        }
                    }
                    .subtleGreenButton()
                    .frame(maxWidth: .infinity)
                }
                
                Button(currentStep == totalSteps ? "Generate Plan" : "Next") {
                    if currentStep == totalSteps {
                        generateWeeklyPlan()
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    }
                }
                .primaryGreenButton()
                .frame(maxWidth: .infinity)
                .disabled(!canProceed)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Views
    private func dietOptionCard(title: String, description: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.primaryGreen.opacity(0.1) : Color(.systemBackground))
                    .stroke(
                        isSelected ? Color.primaryGreen : Color(.systemGray4),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func allergyCard(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.error : Color(.systemBackground))
                        .stroke(
                            isSelected ? Color.error : Color(.systemGray4),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func summaryRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title + ":")
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Text(value)
                .font(.callout)
                .foregroundColor(.primary)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Computed Properties
    private var canProceed: Bool {
        switch currentStep {
        case 1:
            return !planDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2, 3:
            return true // Optional steps
        case 4:
            return !mealPlanStore.isGenerating
        default:
            return false
        }
    }
    
    // MARK: - Helper Methods
    private func stepTitle(for step: Int) -> String {
        switch step {
        case 1: return "Describe Your Ideal Plan"
        case 2: return "Dietary Preferences"
        case 3: return "Allergies & Restrictions"
        case 4: return "Final Settings"
        default: return ""
        }
    }
    
    private func dietTypeDescription(_ dietType: DietType) -> String {
        switch dietType {
        case .vegetarian:
            return "No meat, but includes dairy and eggs"
        case .vegan:
            return "Plant-based, no animal products"
        case .keto:
            return "Low-carb, high-fat diet"
        case .paleo:
            return "Whole foods, no processed foods"
        case .mediterranean:
            return "Fish, vegetables, olive oil focus"
        }
    }
    
    private func setupInitialValues() {
        // Set week start date to next Monday
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysUntilMonday = weekday == 1 ? 1 : (9 - weekday) % 7
        // weekStartDate initialization removed
    }
    
    private func generateWeeklyPlan() {
        let description = planDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let request = AIGenerationRequest(
            description: description,
            dietType: selectedDietType,
            allergies: Array(selectedAllergies),
            dislikes: [],
            calorieTarget: Int(calorieTarget),
            // weekStartDate parameter removed
            additionalRequirements: nil
        )
        
        // Call the workflow callback instead of direct generation
        onGenerationStart(request)
    }
    
    // MARK: - Static Data
    private var descriptionSuggestions: [String] {
        [
            "Healthy family meals with variety for the whole week",
            "Quick weeknight dinners under 30 minutes",
            "Balanced nutrition with plenty of vegetables",
            "Comfort foods that are still nutritious",
            "International cuisine to try new flavors"
        ]
    }
}



// MARK: - Preview
#Preview {
    AIWeeklyGenerationViewWithCallbacks(
        onGenerationStart: { request in
            print("Generation started with: \(request.description)")
        },
        onCancel: {
            print("Generation cancelled")
        }
    )
    .environmentObject(MealPlanStore())
}