//
//  MealPlanAnalysisView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import SwiftUI

struct MealPlanAnalysisView: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedAnalysisType: AnalysisType = .full
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let analysis = mealPlanStore.nutritionAnalysis {
                    AnalysisResultView(analysis: analysis)
                } else if mealPlanStore.isAnalyzing {
                    AnalyzingView()
                } else {
                    AnalysisSetupView(selectedType: $selectedAnalysisType) {
                        performAnalysis()
                    }
                }
            }
            .navigationTitle("Meal Plan Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if mealPlanStore.nutritionAnalysis != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("New Analysis") {
                            mealPlanStore.nutritionAnalysis = nil
                        }
                    }
                }
            }
        }
    }
    
    private func performAnalysis() {
        Task {
            await mealPlanStore.analyzeCurrentMealPlan()
        }
    }
}

// MARK: - Analysis Setup View

struct AnalysisSetupView: View {
    @Binding var selectedType: AnalysisType
    let onAnalyze: () -> Void
    @EnvironmentObject var mealPlanStore: MealPlanStore
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 48))
                    .foregroundColor(.primaryGreen)
                
                Text("Analyze Your Meal Plan")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Get AI-powered insights about your meal plan's nutrition, variety, and balance.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Analysis Type Selection
            VStack(alignment: .leading, spacing: 16) {
                Text("Analysis Type")
                    .font(.headline)
                
                VStack(spacing: 12) {
                    ForEach(AnalysisType.allCases, id: \.self) { type in
                        AnalysisTypeCard(
                            type: type,
                            isSelected: selectedType == type
                        ) {
                            selectedType = type
                        }
                    }
                }
            }
            
            Spacer()
            
            // Analyze Button
            Button("Analyze Meal Plan") {
                onAnalyze()
            }
            .buttonStyle(.borderedProminent)
            .disabled(mealPlanStore.currentMealPlan == nil)
            
            if mealPlanStore.currentMealPlan == nil {
                Text("No meal plan selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct AnalysisTypeCard: View {
    let type: AnalysisType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(typeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .primaryGreen : .secondary)
            }
            .padding()
            .background(isSelected ? Color.primaryGreen.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var typeDescription: String {
        switch type {
        case .nutrition:
            return "Focus on nutritional content and balance"
        case .variety:
            return "Analyze ingredient and cuisine variety"
        case .balance:
            return "Check meal timing and portion balance"
        case .full:
            return "Comprehensive analysis with recommendations"
        }
    }
}

// MARK: - Analyzing View

struct AnalyzingView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Animated Analysis Icon
            ZStack {
                Circle()
                    .stroke(Color.primaryGreen.opacity(0.3), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.primaryGreen, lineWidth: 4)
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: UUID())
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32))
                    .foregroundColor(.primaryGreen)
            }
            
            VStack(spacing: 8) {
                Text("Analyzing Your Meal Plan")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Our AI is reviewing your meal plan for nutrition, variety, and balance...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Analysis Result View

struct AnalysisResultView: View {
    let analysis: MealPlanAnalysis
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        Text("Analysis Complete")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Text("Analysis performed on \(analysis.analysisDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Analysis Stats
                HStack(spacing: 20) {
                    StatCard(
                        title: "Total Recipes",
                        value: "\(analysis.totalRecipes)",
                        icon: "fork.knife"
                    )
                    
                    StatCard(
                        title: "Analysis Type",
                        value: analysis.analysisType.displayName,
                        icon: "chart.bar"
                    )
                }
                
                Divider()
                
                // Analysis Text
                VStack(alignment: .leading, spacing: 12) {
                    Text("AI Analysis & Recommendations")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(analysis.analysisText)
                        .font(.body)
                        .lineSpacing(4)
                }
                
                Divider()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button("Generate Shopping List") {
                        // TODO: Generate shopping list
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    
                    Button("Share Analysis") {
                        // TODO: Share analysis
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.primaryGreen)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    MealPlanAnalysisView()
        .environmentObject(MealPlanStore())
}