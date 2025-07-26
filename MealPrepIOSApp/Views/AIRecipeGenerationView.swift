//
//  AIRecipeGenerationView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/21/25.
//

import SwiftUI

struct AIRecipeGenerationView: View {
    @EnvironmentObject var recipeStore: RecipeStore
    @StateObject private var viewModel = AIRecipeGenerationViewModel()
    @Environment(\.dismiss) private var dismiss
    
    // Form inputs - simplified to just recipe name
    @State private var recipeName = ""
    
    var body: some View {
        NavigationView {
            Group {
                switch viewModel.state {
                case .idle:
                    aiInputForm
                case .generating:
                    generatingView
                case .preview(let aiRecipe):
                    aiRecipePreviewView(aiRecipe)
                case .creating:
                    creatingView
                case .success(let recipe):
                    successView(recipe)
                case .error(let message):
                    errorView(message)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if case .preview = viewModel.state {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Create Recipe") {
                            createRecipeFromAI()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .onAppear {
                viewModel.setRecipeStore(recipeStore)
            }
        }
    }
    
    // MARK: - AI Input Form
    
    private var aiInputForm: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Simple input form - no title section
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What would you like to cook?")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("e.g., Spaghetti Carbonara, Chocolate Chip Cookies, Thai Green Curry...", text: $recipeName, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .font(.body)
                }
                
                Button(action: generateRecipe) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Generate Recipe")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isFormValid ? Color.primaryGreen : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!isFormValid)
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    // MARK: - Loading States
    
    private var generatingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("AI is creating your recipe...")
                .font(.headline)
            
            Text("This may take a few moments")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var creatingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Saving your recipe...")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Preview View
    
    private func aiRecipePreviewView(_ aiRecipe: AIGeneratedRecipe) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Recipe Image
                if let imageUrl = aiRecipe.imageUrl, !imageUrl.isEmpty {
                    AsyncImageView(
                        url: imageUrl,
                        width: UIScreen.main.bounds.width - 32,
                        height: 200,
                        cornerRadius: 12
                    )
                    .padding(.horizontal)
                }
                
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(aiRecipe.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    MarkdownText(aiRecipe.description, font: .body)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Label("\(aiRecipe.prepTime + aiRecipe.cookTime) min", systemImage: "clock")
                        Spacer()
                        Label(aiRecipe.difficulty.displayName, systemImage: "chart.bar")
                        Spacer()
                        if !aiRecipe.cuisine.isEmpty {
                            Label(aiRecipe.cuisine, systemImage: "globe")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Nutrition Info
                if let calories = aiRecipe.nutritionInfo.calories {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nutrition Information")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                            AIRecipeNutritionItem(label: "Calories", value: "\(calories)")
                            if let protein = aiRecipe.nutritionInfo.protein {
                                AIRecipeNutritionItem(label: "Protein", value: protein)
                            }
                            if let carbs = aiRecipe.nutritionInfo.carbohydrates {
                                AIRecipeNutritionItem(label: "Carbs", value: carbs)
                            }
                            if let fat = aiRecipe.nutritionInfo.fat {
                                AIRecipeNutritionItem(label: "Fat", value: fat)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                
                // Ingredients
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ingredients")
                        .font(.headline)
                    
                    ForEach(Array(aiRecipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                        HStack(alignment: .top) {
                            Text("•")
                                .foregroundColor(.primaryGreen)
                                .fontWeight(.bold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ingredient.name)
                                    .fontWeight(.medium)
                                Text(ingredient.amount)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Instructions")
                        .font(.headline)
                    
                    ForEach(Array(aiRecipe.instructions.enumerated()), id: \.offset) { index, instruction in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryGreen)
                                .frame(minWidth: 20, alignment: .leading)
                            
                            Text(instruction)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                        }
                        .padding(.bottom, 4)
                    }
                }
                .padding(.horizontal)
                
                // Tags
                if !aiRecipe.tags.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.headline)
                        
                        FlowLayout(aiRecipe.tags) { tag in
                            Text(tag)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.primaryGreen.opacity(0.1))
                                .foregroundColor(.primaryGreen)
                                .cornerRadius(16)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Success View
    
    private func successView(_ recipe: Recipe) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Recipe Created Successfully!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("\"\(recipe.name)\" has been added to your recipes.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Generation Failed")
                .font(.title)
                .fontWeight(.bold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                viewModel.resetState()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private var isFormValid: Bool {
        !recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func generateRecipe() {
        // Only send the recipe name, AI will figure out everything else
        let request = AIRecipeGenerationRequest(
            name: recipeName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        viewModel.generateRecipe(request)
    }
    
    private func createRecipeFromAI() {
        guard case .preview(let aiRecipe) = viewModel.state else { return }
        
        let request = CreateRecipeFromAIRequest(
            aiRecipeData: aiRecipe,
            saveToAccount: true,
            addToMealPlan: nil,
            mealPlanDay: nil,
            mealPlanType: nil
        )
        
        viewModel.createRecipeFromAI(request)
    }
}

// MARK: - Supporting Views

struct AIRecipeNutritionItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct FlowLayout<Data, Content>: View where Data: RandomAccessCollection, Content: View, Data.Element: Hashable {
    let data: Data
    let content: (Data.Element) -> Content
    
    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], alignment: .leading, spacing: 8) {
            ForEach(Array(data), id: \.self) { item in
                content(item)
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
class AIRecipeGenerationViewModel: ObservableObject {
    @Published var state: AIRecipeGenerationState = .idle
    private let recipeService = RecipeService()
    private weak var recipeStore: RecipeStore?
    
    func setRecipeStore(_ store: RecipeStore) {
        recipeStore = store
    }
    
    func generateRecipe(_ request: AIRecipeGenerationRequest) {
        state = .generating
        
        Task {
            do {
                let aiRecipe = try await recipeService.generateRecipeWithAI(request)
                state = .preview(aiRecipe)
            } catch {
                state = .error("Failed to generate recipe. Please try again.")
            }
        }
    }
    
    func createRecipeFromAI(_ request: CreateRecipeFromAIRequest) {
        state = .creating
        
        Task {
            do {
                let recipe = try await recipeService.createRecipeFromAI(request)
                
                // Update the recipe store with the new recipe
                if let store = recipeStore {
                    store.recipes.insert(recipe, at: 0)
                    store.totalCount += 1
                }
                
                state = .success(recipe)
            } catch {
                state = .error("Failed to create recipe. Please try again.")
            }
        }
    }
    
    func resetState() {
        state = .idle
    }
}

#Preview {
    AIRecipeGenerationView()
}