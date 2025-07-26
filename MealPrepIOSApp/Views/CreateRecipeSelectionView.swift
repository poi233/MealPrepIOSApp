//
//  CreateRecipeSelectionView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/21/25.
//

import SwiftUI

struct CreateRecipeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingAIGenerator = false
    @State private var showingManualCreator = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                Spacer()
                
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primaryGreen, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Create New Recipe")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Choose how you'd like to create your recipe")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Options
                VStack(spacing: 20) {
                    // AI Option
                    Button(action: {
                        showingAIGenerator = true
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(12)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AI Generated")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text("Let AI create a complete recipe for you")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Manual Option
                    Button(action: {
                        showingManualCreator = true
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "pencil")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    LinearGradient(
                                        colors: [.orange, .red],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(12)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Manual Entry")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text("Create your recipe step by step")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Create Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAIGenerator) {
            AIRecipeGenerationView()
        }
        .sheet(isPresented: $showingManualCreator) {
            NavigationView {
                ManualCreateRecipeView()
            }
        }
    }
}

#Preview {
    CreateRecipeSelectionView()
}