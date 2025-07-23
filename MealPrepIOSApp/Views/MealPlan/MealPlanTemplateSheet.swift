//
//  MealPlanTemplateSheet.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/22/25.
//

import SwiftUI

struct MealPlanTemplateSheet: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: TemplateTab = .load
    @State private var templateName = ""
    @State private var templateDescription = ""
    @State private var isSaving = false
    @State private var isLoadingTemplates = false
    @State private var isApplyingTemplate = false
    @State private var selectedTemplate: MealPlanTemplate?
    @State private var availableTemplates: [MealPlanTemplate] = []
    @State private var showingSaveConfirmation = false
    @State private var showingApplyConfirmation = false
    @State private var saveError: String?
    @State private var loadError: String?
    
    enum TemplateTab: String, CaseIterable {
        case load = "Load Template"
        case save = "Save Template"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                Picker("Template Action", selection: $selectedTab) {
                    ForEach(TemplateTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content based on selected tab
                Group {
                    if selectedTab == .load {
                        loadTemplateView
                    } else {
                        saveTemplateView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if selectedTab == .load {
                loadAvailableTemplates()
            }
        }
        .alert("Template Applied!", isPresented: $showingApplyConfirmation) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Template has been applied to your current week.")
        }
        .alert("Template Saved!", isPresented: $showingSaveConfirmation) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your meal plan template has been saved successfully.")
        }
    }
}

// MARK: - Load Template View

extension MealPlanTemplateSheet {
    private var loadTemplateView: some View {
        VStack(spacing: 0) {
            if isLoadingTemplates {
                ProgressView("Loading templates...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if availableTemplates.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Templates Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Create your first template by switching to the 'Save Template' tab.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Retry") {
                        loadAvailableTemplates()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(availableTemplates, id: \.id) { template in
                            TemplateCard(template: template) {
                                applyTemplate(template)
                            }
                        }
                    }
                    .padding()
                }
            }
            
            if let error = loadError {
                VStack {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .load {
                loadAvailableTemplates()
            }
        }
    }
}

// MARK: - Save Template View

extension MealPlanTemplateSheet {
    private var saveTemplateView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Current week preview
                currentWeekPreviewCard
                
                // Template details form
                VStack(alignment: .leading, spacing: 16) {
                    Text("Template Details")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Template Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Enter template name", text: $templateName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Enter description", text: $templateDescription, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3, reservesSpace: true)
                    }
                    
                    // Save button
                    Button(action: {
                        saveCurrentWeekAsTemplate()
                    }) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "folder.badge.plus")
                            }
                            Text(isSaving ? "Saving..." : "Save as Template")
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasCurrentWeekMeals || isSaving)
                    
                    if let error = saveError {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
            .padding()
        }
    }
    
    private var currentWeekPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Week Preview")
                .font(.headline)
                .fontWeight(.semibold)
            
            if hasCurrentWeekMeals {
                VStack(spacing: 8) {
                    ForEach(Array(mealPlanStore.weeklyGrid.dailyMeals.enumerated()), id: \.offset) { index, day in
                        let totalMeals = day.breakfast.count + day.lunch.count + day.dinner.count + day.snack.count
                        if totalMeals > 0 {
                            HStack {
                                Text(day.day)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(width: 80, alignment: .leading)
                                
                                Text("\(totalMeals) meal\(totalMeals == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                // Show first few meal names
                                let allMeals = day.breakfast + day.lunch + day.dinner + day.snack
                                Text(allMeals.prefix(2).map { $0.name }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("No meals planned for current week")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var hasCurrentWeekMeals: Bool {
        !mealPlanStore.weeklyGrid.dailyMeals.allSatisfy { day in
            day.breakfast.isEmpty && day.lunch.isEmpty && day.dinner.isEmpty && day.snack.isEmpty
        }
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: MealPlanTemplate
    let onApply: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let description = template.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Button("Apply") {
                    onApply()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            if let previewMeals = template.previewMeals, !previewMeals.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sample Meals:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(previewMeals.prefix(3).joined(separator: " • "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Template Operations

extension MealPlanTemplateSheet {
    @MainActor
    private func loadAvailableTemplates() async {
        isLoadingTemplates = true
        loadError = nil
        
        do {
            let templates = try await MealPlanTemplateService().getTemplates()
            availableTemplates = templates
        } catch {
            loadError = "Failed to load templates: \(error.localizedDescription)"
            availableTemplates = []
        }
        
        isLoadingTemplates = false
    }
    
    @MainActor
    private func applyTemplate(_ template: MealPlanTemplate) async {
        isApplyingTemplate = true
        
        do {
            // Get template details from backend
            let templateDetail = try await MealPlanTemplateService().getTemplate(id: template.id)
            
            // Create new weekly grid based on template
            var newGrid = WeeklyMealGrid(weekStartDate: mealPlanStore.selectedWeekStartDate)
            
            // Apply template meals to new grid
            for meal in templateDetail.meals {
                if meal.dayOfWeek < newGrid.dailyMeals.count,
                   let recipe = meal.recipe {
                    switch meal.mealType.lowercased() {
                    case "breakfast":
                        newGrid.dailyMeals[meal.dayOfWeek].breakfast.append(recipe)
                    case "lunch":
                        newGrid.dailyMeals[meal.dayOfWeek].lunch.append(recipe)
                    case "dinner":
                        newGrid.dailyMeals[meal.dayOfWeek].dinner.append(recipe)
                    case "snack":
                        newGrid.dailyMeals[meal.dayOfWeek].snack.append(recipe)
                    default:
                        break
                    }
                }
            }
            
            // Update meal plan store
            mealPlanStore.weeklyGrid = newGrid
            mealPlanStore.saveLocalMealPlan()
            
            showingApplyConfirmation = true
            
        } catch {
            loadError = "Failed to apply template: \(error.localizedDescription)"
        }
        
        isApplyingTemplate = false
    }
    
    @MainActor
    private func saveCurrentWeekAsTemplate() async {
        guard !templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSaving = true
        saveError = nil
        
        do {
            // Extract meals from current week
            var meals: [CreateMealPlanTemplateMeal] = []
            
            for (dayIndex, dayMeals) in mealPlanStore.weeklyGrid.dailyMeals.enumerated() {
                // Add breakfast meals
                for recipe in dayMeals.breakfast {
                    meals.append(CreateMealPlanTemplateMeal(
                        recipeId: recipe.id,
                        dayOfWeek: dayIndex,
                        mealType: "breakfast",
                        servingSize: 1.0
                    ))
                }
                
                // Add lunch meals
                for recipe in dayMeals.lunch {
                    meals.append(CreateMealPlanTemplateMeal(
                        recipeId: recipe.id,
                        dayOfWeek: dayIndex,
                        mealType: "lunch",
                        servingSize: 1.0
                    ))
                }
                
                // Add dinner meals
                for recipe in dayMeals.dinner {
                    meals.append(CreateMealPlanTemplateMeal(
                        recipeId: recipe.id,
                        dayOfWeek: dayIndex,
                        mealType: "dinner",
                        servingSize: 1.0
                    ))
                }
                
                // Add snack meals
                for recipe in dayMeals.snack {
                    meals.append(CreateMealPlanTemplateMeal(
                        recipeId: recipe.id,
                        dayOfWeek: dayIndex,
                        mealType: "snack",
                        servingSize: 1.0
                    ))
                }
            }
            
            // Create template request
            let templateRequest = CreateMealPlanTemplateRequest(
                name: templateName.trimmingCharacters(in: .whitespacesAndNewlines),
                description: templateDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
                    ? nil : templateDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                meals: meals
            )
            
            // Call service to save template
            let _ = try await MealPlanTemplateService().createTemplate(templateRequest)
            
            showingSaveConfirmation = true
            
        } catch {
            saveError = "Failed to save template: \(error.localizedDescription)"
        }
        
        isSaving = false
    }
    
    private func loadAvailableTemplates() {
        Task {
            await loadAvailableTemplates()
        }
    }
    
    private func applyTemplate(_ template: MealPlanTemplate) {
        Task {
            await applyTemplate(template)
        }
    }
    
    private func saveCurrentWeekAsTemplate() {
        Task {
            await saveCurrentWeekAsTemplate()
        }
    }
}

#Preview {
    MealPlanTemplateSheet()
        .environmentObject(MealPlanStore())
}