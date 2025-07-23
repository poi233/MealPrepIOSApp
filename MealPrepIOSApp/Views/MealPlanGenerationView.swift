//
//  MealPlanGenerationView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import SwiftUI

struct MealPlanGenerationView: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var planDescription = ""
    @State private var selectedDietType: DietType?
    @State private var allergies: [String] = []
    @State private var dislikes: [String] = []
    @State private var calorieTarget: Double = 2000
    @State private var weekStartDate = Date()
    @State private var additionalRequirements = ""
    @State private var selectedTemplate: MealPlanGenerationTemplate?
    
    @State private var newAllergy = ""
    @State private var newDislike = ""
    @State private var showingTemplates = false
    
    private let commonAllergies = ["Nuts", "Shellfish", "Dairy", "Eggs", "Soy", "Gluten", "Fish"]
    private let commonDislikes = ["Mushrooms", "Onions", "Spicy Food", "Seafood", "Vegetables", "Meat"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Meal Plan Description") {
                    TextField("Describe your ideal meal plan...", text: $planDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                }
                
                Section("Dietary Preferences") {
                    Picker("Diet Type", selection: $selectedDietType) {
                        Text("No Preference").tag(nil as DietType?)
                        ForEach(DietType.allCases, id: \.self) { dietType in
                            Text(dietType.displayName).tag(dietType as DietType?)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Calorie Target: \(Int(calorieTarget))")
                            .font(.subheadline)
                        Slider(value: $calorieTarget, in: 1200...3500, step: 50)
                    }
                }
                
                Section("Allergies & Restrictions") {
                    // Current allergies
                    if !allergies.isEmpty {
                        ForEach(allergies, id: \.self) { allergy in
                            HStack {
                                Text(allergy)
                                Spacer()
                                Button("Remove") {
                                    allergies.removeAll { $0 == allergy }
                                }
                                .foregroundColor(.red)
                                .font(.caption)
                            }
                        }
                    }
                    
                    // Add allergy
                    HStack {
                        TextField("Add allergy", text: $newAllergy)
                        Button("Add") {
                            addAllergy()
                        }
                        .disabled(newAllergy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    // Common allergies
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(commonAllergies, id: \.self) { allergy in
                                Button(allergy) {
                                    if !allergies.contains(allergy) {
                                        allergies.append(allergy)
                                    }
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(allergies.contains(allergy) ? Color.red.opacity(0.2) : Color(.systemGray5))
                                .foregroundColor(allergies.contains(allergy) ? .red : .primary)
                                .cornerRadius(8)
                                .disabled(allergies.contains(allergy))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Section("Dislikes") {
                    // Current dislikes
                    if !dislikes.isEmpty {
                        ForEach(dislikes, id: \.self) { dislike in
                            HStack {
                                Text(dislike)
                                Spacer()
                                Button("Remove") {
                                    dislikes.removeAll { $0 == dislike }
                                }
                                .foregroundColor(.red)
                                .font(.caption)
                            }
                        }
                    }
                    
                    // Add dislike
                    HStack {
                        TextField("Add dislike", text: $newDislike)
                        Button("Add") {
                            addDislike()
                        }
                        .disabled(newDislike.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    // Common dislikes
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(commonDislikes, id: \.self) { dislike in
                                Button(dislike) {
                                    if !dislikes.contains(dislike) {
                                        dislikes.append(dislike)
                                    }
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(dislikes.contains(dislike) ? Color.orange.opacity(0.2) : Color(.systemGray5))
                                .foregroundColor(dislikes.contains(dislike) ? .orange : .primary)
                                .cornerRadius(8)
                                .disabled(dislikes.contains(dislike))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Section("Week Planning") {
                    DatePicker("Week Start Date", selection: $weekStartDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                }
                
                Section("Additional Requirements") {
                    TextField("Any special requirements or preferences...", text: $additionalRequirements, axis: .vertical)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.sentences)
                }
                
                Section("Templates") {
                    Button("Choose from Templates") {
                        showingTemplates = true
                    }
                    .foregroundColor(.accentColor)
                    
                    if let template = selectedTemplate {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(template.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            Button("Remove") {
                                selectedTemplate = nil
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Generate Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Generate") {
                        generateMealPlan()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid || mealPlanStore.isGenerating)
                }
            }
            .disabled(mealPlanStore.isGenerating)
            .sheet(isPresented: $showingTemplates) {
                MealPlanTemplatesView(selectedTemplate: $selectedTemplate)
            }
            .onAppear {
                setupInitialValues()
            }
        }
    }
    
    private var isFormValid: Bool {
        !planDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func setupInitialValues() {
        // Set week start date to next Monday
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysUntilMonday = (9 - weekday) % 7
        weekStartDate = calendar.date(byAdding: .day, value: daysUntilMonday, to: today) ?? today
    }
    
    private func addAllergy() {
        let trimmed = newAllergy.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !allergies.contains(trimmed) {
            allergies.append(trimmed)
            newAllergy = ""
        }
    }
    
    private func addDislike() {
        let trimmed = newDislike.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !dislikes.contains(trimmed) {
            dislikes.append(trimmed)
            newDislike = ""
        }
    }
    
    private func generateMealPlan() {
        let description = planDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let additionalReqs = additionalRequirements.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            let success = await mealPlanStore.generateCustomMealPlan(
                description: description,
                dietType: selectedDietType,
                allergies: allergies,
                dislikes: dislikes,
                calorieTarget: Int(calorieTarget),
                weekStartDate: weekStartDate,
                additionalRequirements: additionalReqs.isEmpty ? nil : additionalReqs
            )
            
            await MainActor.run {
                if success {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Templates View

struct MealPlanTemplatesView: View {
    @Binding var selectedTemplate: MealPlanGenerationTemplate?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(MealPlanGenerationTemplate.allTemplates, id: \.id) { template in
                    TemplateRow(
                        template: template,
                        isSelected: selectedTemplate?.id == template.id
                    ) {
                        selectedTemplate = template
                        dismiss()
                    }
                }
            }
            .navigationTitle("Meal Plan Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TemplateRow: View {
    let template: MealPlanGenerationTemplate
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(template.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(template.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    // Tags
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(template.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Types for Generation View

struct MealPlanGenerationTemplate: Identifiable {
    let id: String
    let name: String
    let description: String
    let tags: [String]
    
    static let allTemplates: [MealPlanGenerationTemplate] = [
        MealPlanGenerationTemplate(
            id: "balanced-week",
            name: "Balanced Week",
            description: "A well-rounded meal plan with variety in proteins, vegetables, and grains",
            tags: ["Balanced", "Nutritious", "Family-Friendly"]
        ),
        MealPlanGenerationTemplate(
            id: "mediterranean",
            name: "Mediterranean Style",
            description: "Fresh, healthy meals inspired by Mediterranean cuisine",
            tags: ["Mediterranean", "Heart-Healthy", "Fish", "Vegetables"]
        ),
        MealPlanGenerationTemplate(
            id: "quick-easy",
            name: "Quick & Easy",
            description: "Simple meals that can be prepared in 30 minutes or less",
            tags: ["Quick", "Simple", "30-min", "Busy Schedule"]
        ),
        MealPlanGenerationTemplate(
            id: "vegetarian",
            name: "Vegetarian Focus",
            description: "Plant-based meals with complete proteins and nutrients",
            tags: ["Vegetarian", "Plant-Based", "Protein-Rich"]
        )
    ]
}

#Preview {
    MealPlanGenerationView()
        .environmentObject(MealPlanStore())
}