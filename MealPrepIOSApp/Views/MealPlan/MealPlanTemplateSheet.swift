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
    @State private var selectedWeekForSave: Date
    @State private var showingWeekPicker = false
    
    init() {
        let calendar = Calendar.current
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        _selectedWeekForSave = State(initialValue: currentWeekStart)
    }
    
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
            print("🎬 [MealPlanTemplateSheet] Template sheet appeared")
            print("📑 [MealPlanTemplateSheet] Selected tab: \(selectedTab.rawValue)")
            
            if selectedTab == .load {
                print("🔄 [MealPlanTemplateSheet] Auto-loading templates for Load tab")
                loadAvailableTemplates()
            } else {
                print("💾 [MealPlanTemplateSheet] Save tab selected, waiting for user action")
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
                // Week selection
                weekSelectionCard
                
                // Selected week preview
                selectedWeekPreviewCard
                
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
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Enter description", text: $templateDescription, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3, reservesSpace: true)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
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
                    .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasSelectedWeekMeals || isSaving)
                    
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
    
    private var weekSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Week to Save as Template")
                .font(.headline)
                .fontWeight(.semibold)
            
            Button(action: {
                showingWeekPicker = true
            }) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Selected Week")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatWeekRange(from: selectedWeekForSave))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        .fill(Color.accentColor.opacity(0.05))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .sheet(isPresented: $showingWeekPicker) {
            WeekPickerSheet(selectedDate: $selectedWeekForSave)
        }
    }
    
    private var selectedWeekPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Week Preview")
                .font(.headline)
                .fontWeight(.semibold)
            
            if hasSelectedWeekMeals {
                VStack(spacing: 8) {
                    ForEach(Array(getSelectedWeekMeals().enumerated()), id: \.offset) { index, day in
                        let totalMeals = day.breakfast.count + day.lunch.count + day.dinner.count
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
                                let allMeals = day.breakfast + day.lunch + day.dinner
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
                    Text("No meals planned for selected week")
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
    
    private var hasSelectedWeekMeals: Bool {
        !getSelectedWeekMeals().allSatisfy { day in
            day.breakfast.isEmpty && day.lunch.isEmpty && day.dinner.isEmpty
        }
    }
    
    private func getSelectedWeekMeals() -> [DailyMealSlots] {
        // If selected week is current week, use current week's data
        if Calendar.current.isDate(selectedWeekForSave, equalTo: mealPlanStore.selectedWeekStartDate, toGranularity: .weekOfYear) {
            return mealPlanStore.weeklyGrid.dailyMeals
        } else {
            // Load data from local storage for the selected week
            if let storedGrid = LocalMealPlanStorage.shared.loadWeeklyMealPlan(for: selectedWeekForSave) {
                return storedGrid.dailyMeals
            } else {
                // Return empty week if no stored data
                return WeeklyMealGrid(weekStartDate: selectedWeekForSave).dailyMeals
            }
        }
    }
    
    private func formatWeekRange(from date: Date) -> String {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startString = formatter.string(from: weekStart)
        let endString = formatter.string(from: weekEnd)
        
        // Add year if different from current year
        let currentYear = calendar.component(.year, from: Date())
        let weekYear = calendar.component(.year, from: weekStart)
        
        if weekYear != currentYear {
            return "\(startString) - \(endString), \(weekYear)"
        } else {
            return "\(startString) - \(endString)"
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
        print("🔄 [LoadTemplate] Starting to load available templates...")
        isLoadingTemplates = true
        loadError = nil
        
        do {
            print("🌐 [LoadTemplate] Making API call to backend: GET /meal-plans/")
            print("🔐 [LoadTemplate] Using authenticated request...")
            
            let templates = try await MealPlanTemplateService().getTemplates()
            
            print("✅ [LoadTemplate] Successfully received \(templates.count) templates from backend")
            print("📋 [LoadTemplate] Template details:")
            for (index, template) in templates.enumerated() {
                print("   \(index + 1). ID: \(template.id)")
                print("      Name: \(template.name)")
                print("      Description: \(template.description ?? "No description")")
                print("      Category: \(template.category.rawValue)")
                print("      Preview meals: \(template.previewMeals?.joined(separator: ", ") ?? "None")")
            }
            
            availableTemplates = templates
            
            if templates.isEmpty {
                print("⚠️ [LoadTemplate] No templates found for current user")
            } else {
                print("🎉 [LoadTemplate] Templates loaded successfully and set to UI")
            }
            
        } catch {
            print("❌ [LoadTemplate] Failed to load templates from backend")
            print("🚨 [LoadTemplate] Error details: \(error)")
            if let networkError = error as? NetworkError {
                print("🌐 [LoadTemplate] Network error type: \(networkError)")
            }
            
            loadError = "Failed to load templates: \(error.localizedDescription)"
            availableTemplates = []
        }
        
        isLoadingTemplates = false
        print("🔄 [LoadTemplate] Load operation completed")
    }
    
    @MainActor
    private func applyTemplate(_ template: MealPlanTemplate) async {
        print("🎯 [ApplyTemplate] Starting to apply template: \(template.name)")
        print("📍 [ApplyTemplate] Template ID: \(template.id)")
        isApplyingTemplate = true
        
        do {
            print("🌐 [ApplyTemplate] Fetching template details from backend: GET /meal-plans/\(template.id)/")
            
            // Get template details from backend
            let templateDetail = try await MealPlanTemplateService().getTemplate(id: template.id)
            
            print("✅ [ApplyTemplate] Template details received:")
            print("   📝 Name: \(templateDetail.name)")
            print("   📖 Description: \(templateDetail.description ?? "No description")")
            print("   🍽️ Total meals: \(templateDetail.meals.count)")
            
            // Create new weekly grid based on template
            var newGrid = WeeklyMealGrid(weekStartDate: mealPlanStore.selectedWeekStartDate)
            print("📅 [ApplyTemplate] Creating new meal plan for week starting: \(mealPlanStore.selectedWeekStartDate)")
            
            var appliedMealsCount = 0
            // Apply template meals to new grid
            for meal in templateDetail.meals {
                print("🔄 [ApplyTemplate] Processing meal - Day: \(meal.dayOfWeek), Type: \(meal.mealType), Recipe: \(meal.recipe?.name ?? "Unknown")")
                
                if meal.dayOfWeek < newGrid.dailyMeals.count,
                   let recipe = meal.recipe {
                    switch meal.mealType.lowercased() {
                    case "breakfast":
                        newGrid.dailyMeals[meal.dayOfWeek].breakfast.append(recipe)
                        appliedMealsCount += 1
                        print("   ✅ Added to breakfast")
                    case "lunch":
                        newGrid.dailyMeals[meal.dayOfWeek].lunch.append(recipe)
                        appliedMealsCount += 1
                        print("   ✅ Added to lunch")
                    case "dinner":
                        newGrid.dailyMeals[meal.dayOfWeek].dinner.append(recipe)
                        appliedMealsCount += 1
                        print("   ✅ Added to dinner")
                    default:
                        print("   ⚠️ Unknown meal type: \(meal.mealType)")
                        break
                    }
                } else {
                    print("   🚨 Failed to add meal - Invalid day (\(meal.dayOfWeek)) or missing recipe")
                }
            }
            
            print("📊 [ApplyTemplate] Applied \(appliedMealsCount) out of \(templateDetail.meals.count) meals")
            
            // Update meal plan store
            mealPlanStore.weeklyGrid = newGrid
            mealPlanStore.saveLocalMealPlan()
            
            print("💾 [ApplyTemplate] Meal plan saved to local storage")
            print("🎉 [ApplyTemplate] Template applied successfully!")
            
            showingApplyConfirmation = true
            
        } catch {
            print("❌ [ApplyTemplate] Failed to apply template")
            print("🚨 [ApplyTemplate] Error details: \(error)")
            if let networkError = error as? NetworkError {
                print("🌐 [ApplyTemplate] Network error type: \(networkError)")
            }
            
            loadError = "Failed to apply template: \(error.localizedDescription)"
        }
        
        isApplyingTemplate = false
        print("🔚 [ApplyTemplate] Apply operation completed")
    }
    
    @MainActor
    private func saveCurrentWeekAsTemplate() async {
        guard !templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            print("⚠️ [SaveTemplate] Template name is empty, aborting save")
            return 
        }
        
        print("💾 [SaveTemplate] Starting to save current week as template...")
        let cleanName = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = templateDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("📝 [SaveTemplate] Template info:")
        print("   Name: '\(cleanName)'")
        print("   Description: '\(cleanDescription.isEmpty ? "No description" : cleanDescription)'")
        print("   Selected week: \(formatWeekRange(from: selectedWeekForSave))")
        
        isSaving = true
        saveError = nil
        
        do {
            // Extract meals from selected week
            print("🔍 [SaveTemplate] Extracting meals from local storage for selected week...")
            let selectedWeekMeals = getSelectedWeekMeals()
            
            var meals: [CreateMealPlanTemplateMeal] = []
            var totalMealCount = 0
            
            print("📊 [SaveTemplate] Processing meals by day:")
            
            for (dayIndex, dayMeals) in selectedWeekMeals.enumerated() {
                let dayName = Calendar.current.weekdaySymbols[dayIndex]
                let dayTotal = dayMeals.breakfast.count + dayMeals.lunch.count + dayMeals.dinner.count
                totalMealCount += dayTotal
                
                print("   📅 \(dayName) (Day \(dayIndex)): \(dayTotal) meals")
                
                // Add breakfast meals
                for (index, recipe) in dayMeals.breakfast.enumerated() {
                    let templateMeal = CreateMealPlanTemplateMeal(
                        recipeId: recipe.id,
                        dayOfWeek: dayIndex,
                        mealType: "breakfast",
                        servingSize: 1.0
                    )
                    meals.append(templateMeal)
                    print("     🌅 Breakfast \(index + 1): \(recipe.name) (ID: \(recipe.id))")
                }
                
                // Add lunch meals
                for (index, recipe) in dayMeals.lunch.enumerated() {
                    let templateMeal = CreateMealPlanTemplateMeal(
                        recipeId: recipe.id,
                        dayOfWeek: dayIndex,
                        mealType: "lunch",
                        servingSize: 1.0
                    )
                    meals.append(templateMeal)
                    print("     🌞 Lunch \(index + 1): \(recipe.name) (ID: \(recipe.id))")
                }
                
                // Add dinner meals
                for (index, recipe) in dayMeals.dinner.enumerated() {
                    let templateMeal = CreateMealPlanTemplateMeal(
                        recipeId: recipe.id,
                        dayOfWeek: dayIndex,
                        mealType: "dinner",
                        servingSize: 1.0
                    )
                    meals.append(templateMeal)
                    print("     🌙 Dinner \(index + 1): \(recipe.name) (ID: \(recipe.id))")
                }
            }
            
            print("🍽️ [SaveTemplate] Total meals to save: \(totalMealCount)")
            
            if meals.isEmpty {
                print("⚠️ [SaveTemplate] No meals found in selected week, cannot create empty template")
                saveError = "Cannot save empty template. Please add some meals to the selected week first."
                isSaving = false
                return
            }
            
            // Create template request
            let templateRequest = CreateMealPlanTemplateRequest(
                name: cleanName,
                description: cleanDescription.isEmpty ? nil : cleanDescription,
                meals: meals
            )
            
            print("🔄 [SaveTemplate] Converting to backend API format...")
            print("📤 [SaveTemplate] Request payload:")
            print("   {")
            print("     name: \"\(templateRequest.name)\"")
            print("     description: \"\(templateRequest.description ?? "null")\"")
            print("     meals: [")
            for (index, meal) in templateRequest.meals.enumerated() {
                print("       \(index + 1). {")
                print("         recipe_id: \"\(meal.recipeId)\"")
                print("         day_of_week: \(meal.dayOfWeek)")
                print("         meal_type: \"\(meal.mealType)\"")
                print("         serving_size: \(meal.servingSize)")
                print("       }")
            }
            print("     ]")
            print("   }")
            
            print("🌐 [SaveTemplate] Making API call to backend: POST /meal-plans/")
            print("🔐 [SaveTemplate] Using authenticated request...")
            
            // Call service to save template
            let response = try await MealPlanTemplateService().createTemplate(templateRequest)
            
            print("✅ [SaveTemplate] Template saved successfully!")
            print("📋 [SaveTemplate] Response details:")
            print("   Template ID: \(response.id)")
            print("   Template Name: \(response.name)")
            print("   Created At: \(response.createdAt?.description ?? "Unknown")")
            print("   Updated At: \(response.updatedAt?.description ?? "Unknown")")
            
            showingSaveConfirmation = true
            
        } catch {
            print("❌ [SaveTemplate] Failed to save template")
            print("🚨 [SaveTemplate] Error details: \(error)")
            if let networkError = error as? NetworkError {
                print("🌐 [SaveTemplate] Network error type: \(networkError)")
            }
            
            saveError = "Failed to save template: \(error.localizedDescription)"
        }
        
        isSaving = false
        print("🔚 [SaveTemplate] Save operation completed")
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

// MARK: - Week Picker Sheet

struct WeekPickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    @State private var tempSelectedDate: Date
    
    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        self._tempSelectedDate = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Week selection list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(availableWeeks, id: \.self) { weekStart in
                            WeekRowView(
                                weekStart: weekStart,
                                isSelected: Calendar.current.isDate(weekStart, equalTo: tempSelectedDate, toGranularity: .weekOfYear)
                            )
                            .onTapGesture {
                                tempSelectedDate = weekStart
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Select Week")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        selectedDate = tempSelectedDate
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var availableWeeks: [Date] {
        let calendar = Calendar.current
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        
        var weeks: [Date] = []
        
        // Add past 4 weeks
        for i in stride(from: -4, to: 0, by: 1) {
            if let weekStart = calendar.date(byAdding: .weekOfYear, value: i, to: currentWeekStart) {
                weeks.append(weekStart)
            }
        }
        
        // Add current week
        weeks.append(currentWeekStart)
        
        // Add future 4 weeks
        for i in 1...4 {
            if let weekStart = calendar.date(byAdding: .weekOfYear, value: i, to: currentWeekStart) {
                weeks.append(weekStart)
            }
        }
        
        return weeks
    }
}

struct WeekRowView: View {
    let weekStart: Date
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(weekRangeText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(weekStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.title3)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
    }
    
    private var weekRangeText: String {
        let calendar = Calendar.current
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startString = formatter.string(from: weekStart)
        let endString = formatter.string(from: weekEnd)
        
        return "\(startString) - \(endString)"
    }
    
    private var weekStatusText: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDate(weekStart, equalTo: now, toGranularity: .weekOfYear) {
            return "This Week"
        } else if weekStart < now {
            return "Past Week"
        } else {
            return "Future Week"
        }
    }
}

#Preview {
    MealPlanTemplateSheet()
        .environmentObject(MealPlanStore())
}