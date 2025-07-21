//
//  DefaultImageDemoView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import SwiftUI

struct DefaultImageDemoView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    Text("Beautiful Default Recipe Images")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.top)
                    
                    Text("Now your recipes look amazing even without photos!")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Standard Style (for Recipe Cards)
                    VStack(spacing: 16) {
                        Text("Recipe Cards Style")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 16) {
                            DefaultRecipeImageView(width: 120, height: 120)
                            DefaultRecipeImageView(width: 120, height: 90)
                            DefaultRecipeImageView(width: 120, height: 150)
                        }
                        
                        Text("Used in: Recipe lists and search results")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Elegant Style (for Favorites)
                    VStack(spacing: 16) {
                        Text("Favorites Style")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 16) {
                            DefaultRecipeImageView_Elegant(width: 120, height: 120)
                            DefaultRecipeImageView_Elegant(width: 120, height: 90)
                            DefaultRecipeImageView_Elegant(width: 120, height: 150)
                        }
                        
                        Text("Used in: Favorite recipe collections")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Warm Style (for Details)
                    VStack(spacing: 16) {
                        Text("Recipe Details Style")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            DefaultRecipeImageView_Warm(width: 280, height: 180)
                            
                            HStack(spacing: 16) {
                                DefaultRecipeImageView_Warm(width: 100, height: 100)
                                DefaultRecipeImageView_Warm(width: 100, height: 100)
                                DefaultRecipeImageView_Warm(width: 60, height: 60)
                            }
                        }
                        
                        Text("Used in: Recipe detail pages and editing forms")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Features List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("✨ Features")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(icon: "paintbrush.fill", text: "Beautiful gradient backgrounds")
                            FeatureRow(icon: "sparkles", text: "Subtle animation effects")
                            FeatureRow(icon: "fork.knife", text: "Food-themed icons")
                            FeatureRow(icon: "heart.fill", text: "Matches your app's Magic UI style")
                            FeatureRow(icon: "iphone", text: "Responsive design for all screen sizes")
                            FeatureRow(icon: "swift", text: "Built with SwiftUI for optimal performance")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationTitle("Default Images")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    DefaultImageDemoView()
}