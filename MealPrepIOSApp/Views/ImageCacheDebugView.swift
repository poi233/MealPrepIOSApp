//
//  ImageCacheDebugView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/27/25.
//

import SwiftUI

// MARK: - Image Cache Debug View

struct ImageCacheDebugView: View {
    @StateObject private var cacheManager = RecipeImageCacheManager.shared
    @State private var cacheStats: ImageCacheStatistics?
    @State private var isLoading = false
    @State private var testImageUrl = "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&h=300&fit=crop"
    @State private var showingClearConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Cache Statistics") {
                    if let stats = cacheStats {
                        HStack {
                            Text("Total Images")
                            Spacer()
                            Text("\(stats.totalImages)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Disk Usage")
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(stats.formattedDiskSize)
                                    .foregroundColor(.secondary)
                                Text("\(Int(stats.diskUsagePercentage * 100))% of \(stats.formattedMaxSize)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        ProgressView(value: stats.diskUsagePercentage)
                            .progressViewStyle(LinearProgressViewStyle(tint: diskUsageColor(stats.diskUsagePercentage)))
                    } else {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading cache statistics...")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Refresh Statistics") {
                        Task {
                            await refreshStats()
                        }
                    }
                }
                
                Section("Test Image Loading") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test URL:")
                            .font(.headline)
                        
                        TextField("Image URL", text: $testImageUrl)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        HStack(spacing: 16) {
                            AsyncImageView(
                                url: testImageUrl,
                                width: 100,
                                height: 100,
                                cornerRadius: 8,
                                useCache: true
                            )
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Cached Image")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button("Preload Image") {
                                    Task {
                                        await cacheManager.preloadImage(from: testImageUrl)
                                        await refreshStats()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                                
                                Button("Remove from Cache") {
                                    Task {
                                        await cacheManager.removeImageFromCache(urlString: testImageUrl)
                                        await refreshStats()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                        }
                    }
                }
                
                Section("Cache Management") {
                    Button("Clear All Cache", role: .destructive) {
                        showingClearConfirmation = true
                    }
                    
                    Button("Test Recipe Images") {
                        Task {
                            await testRecipeImages()
                        }
                    }
                    .disabled(isLoading)
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Testing image cache...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Sample Recipe Images") {
                    let sampleUrls = [
                        "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&h=300&fit=crop",
                        "https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=400&h=300&fit=crop",
                        "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=400&h=300&fit=crop",
                        "https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=400&h=300&fit=crop"
                    ]
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                        ForEach(Array(sampleUrls.enumerated()), id: \.offset) { index, url in
                            VStack(spacing: 4) {
                                AsyncImageView(
                                    url: url,
                                    width: 120,
                                    height: 90,
                                    cornerRadius: 8,
                                    useCache: true
                                )
                                
                                Text("Sample \(index + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Image Cache Debug")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await refreshStats()
            }
            .alert("Clear Cache", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    Task {
                        await cacheManager.clearCache()
                        await refreshStats()
                    }
                }
            } message: {
                Text("This will remove all cached recipe images. They will be re-downloaded when needed.")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func refreshStats() async {
        let stats = await cacheManager.getCacheStatistics()
        await MainActor.run {
            self.cacheStats = stats
        }
    }
    
    private func diskUsageColor(_ percentage: Double) -> Color {
        if percentage < 0.7 {
            return .green
        } else if percentage < 0.9 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func testRecipeImages() async {
        await MainActor.run {
            isLoading = true
        }
        
        let testUrls = [
            "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&h=300&fit=crop",
            "https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=400&h=300&fit=crop",
            "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=400&h=300&fit=crop"
        ]
        
        // Preload test images
        for url in testUrls {
            await cacheManager.preloadImage(from: url)
        }
        
        await refreshStats()
        
        await MainActor.run {
            isLoading = false
        }
    }
}

// MARK: - Preview

#Preview {
    ImageCacheDebugView()
}