//
//  AsyncImageView.swift
//  MealPrepIOSApp
//
//  Updated by AI Assistant on 7/27/25.
//  Added RecipeImageCacheManager integration for local image caching
//

import SwiftUI
import UIKit

// MARK: - Enhanced AsyncImage with Local Caching

struct AsyncImageView: View {
    let url: String?
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let contentMode: SwiftUI.ContentMode
    let useCache: Bool
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @State private var hasError = false
    @StateObject private var imageCache = RecipeImageCacheManager.shared
    
    init(
        url: String?,
        width: CGFloat = 150,
        height: CGFloat = 150,
        cornerRadius: CGFloat = 12,
        contentMode: SwiftUI.ContentMode = .fill,
        useCache: Bool = true
    ) {
        self.url = url
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.contentMode = contentMode
        self.useCache = useCache
    }
    
    var body: some View {
        ZStack {
            if useCache && url != nil {
                // Use cached image loading
                Group {
                    if isLoading {
                        LoadingImageView(width: width, height: height)
                    } else if let loadedImage = loadedImage {
                        Image(uiImage: loadedImage)
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                            .frame(width: width, height: height)
                            .clipped()
                            .transition(.opacity.animation(.easeOut(duration: 0.3)))
                    } else {
                        // Error state - show default image
                        DefaultRecipeImageView_Elegant(width: width, height: height)
                            .transition(.opacity.animation(.easeOut(duration: 0.3)))
                    }
                }
                .task {
                    await loadCachedImage()
                }
            } else if let url = url, let imageURL = URL(string: url) {
                // Fallback to standard AsyncImage when cache is disabled
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        LoadingImageView(width: width, height: height)
                            .onAppear {
                                isLoading = true
                                hasError = false
                            }
                        
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                            .frame(width: width, height: height)
                            .clipped()
                            .onAppear {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    isLoading = false
                                    hasError = false
                                }
                            }
                        
                    case .failure(_):
                        DefaultRecipeImageView_Elegant(width: width, height: height)
                            .onAppear {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    isLoading = false
                                    hasError = true
                                }
                            }
                        
                    @unknown default:
                        LoadingImageView(width: width, height: height)
                    }
                }
            } else {
                // No URL provided - show default image
                DefaultRecipeImageView_Elegant(width: width, height: height)
                    .onAppear {
                        isLoading = false
                        hasError = false
                    }
            }
        }
        .frame(width: width, height: height)
        .cornerRadius(cornerRadius)
        .animation(.easeInOut(duration: 0.3), value: isLoading)
        .animation(.easeInOut(duration: 0.3), value: hasError)
    }
    
    // MARK: - Cache Loading
    
    private func loadCachedImage() async {
        guard let url = url, !url.isEmpty else {
            await MainActor.run {
                isLoading = false
                hasError = false
            }
            return
        }
        
        do {
            let cachedImage = await imageCache.getCachedImage(from: url)
            
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.loadedImage = cachedImage
                    self.isLoading = false
                    self.hasError = cachedImage == nil
                }
            }
        }
    }
}

// MARK: - Loading Image View with Animation

struct LoadingImageView: View {
    let width: CGFloat
    let height: CGFloat
    
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                colors: [
                    Color(.systemGray5),
                    Color(.systemGray4),
                    Color(.systemGray5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Shimmer effect
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.4),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .rotationEffect(.degrees(30))
                .offset(x: shimmerOffset)
                .animation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                    value: shimmerOffset
                )
            
            // Loading icon with pulse animation
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: min(width, height) * 0.2, weight: .light))
                    .foregroundColor(.secondary.opacity(0.6))
                    .scaleEffect(pulseScale)
                    .animation(
                        Animation.easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true),
                        value: pulseScale
                    )
                
                // Loading dots
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 4, height: 4)
                            .scaleEffect(isAnimating ? 1.0 : 0.5)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                value: isAnimating
                            )
                    }
                }
            }
        }
        .frame(width: width, height: height)
        .onAppear {
            isAnimating = true
            pulseScale = 1.2
            shimmerOffset = width + 200
        }
        .onDisappear {
            isAnimating = false
            pulseScale = 1.0
        }
    }
}

// MARK: - Compact Loading View for Small Images

struct CompactLoadingImageView: View {
    let size: CGFloat
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Simple gradient background
            LinearGradient(
                colors: [Color(.systemGray5), Color(.systemGray4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Simple loading indicator
            ProgressView()
                .scaleEffect(0.8)
                .tint(.secondary)
        }
        .frame(width: size, height: size)
        .cornerRadius(8)
    }
}

// MARK: - Recipe Image View (Convenience wrapper)

struct RecipeImageView: View {
    let recipe: Recipe
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let showLoadingAnimation: Bool
    let useCache: Bool
    
    init(
        recipe: Recipe,
        width: CGFloat = 150,
        height: CGFloat = 150,
        cornerRadius: CGFloat = 12,
        showLoadingAnimation: Bool = true,
        useCache: Bool = true
    ) {
        self.recipe = recipe
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.showLoadingAnimation = showLoadingAnimation
        self.useCache = useCache
    }
    
    var body: some View {
        AsyncImageView(
            url: recipe.imageUrl,
            width: width,
            height: height,
            cornerRadius: cornerRadius,
            useCache: useCache && showLoadingAnimation
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            // Loading state
            LoadingImageView(width: 120, height: 120)
            
            // With URL (cached)
            AsyncImageView(
                url: "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&h=300&fit=crop",
                width: 120,
                height: 120,
                useCache: true
            )
            
            // With URL (no cache)
            AsyncImageView(
                url: "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&h=300&fit=crop",
                width: 120,
                height: 120,
                useCache: false
            )
            
            // No URL (default)
            AsyncImageView(
                url: nil,
                width: 120,
                height: 120
            )
        }
        
        Text("AsyncImageView Examples")
            .font(.headline)
    }
    .padding()
}