//
//  DefaultRecipeImageView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import SwiftUI

struct DefaultRecipeImageView: View {
    let width: CGFloat
    let height: CGFloat

    init(width: CGFloat = 150, height: CGFloat = 150) {
        self.width = width == .infinity ? 200 : width // Handle infinity case
        self.height = height
    }

    var body: some View {
        ZStack {
            // Beautiful gradient background
            LinearGradient(
                colors: [
                    Color(.systemOrange).opacity(0.8),
                    Color(.systemRed).opacity(0.6),
                    Color(.systemPink).opacity(0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative pattern overlay
            ZStack {
                // Background pattern
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: width * 0.8, height: width * 0.8)
                    .offset(x: -width * 0.2, y: -height * 0.2)

                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: width * 0.6, height: width * 0.6)
                    .offset(x: width * 0.15, y: height * 0.15)

                // Central cooking icon
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: min(width, height) * 0.2, weight: .light))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)

                    Text("Recipe")
                        .font(.system(size: min(width, height) * 0.08, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0.5, y: 0.5)
                }
            }

            // Simple sparkle effect (static for better performance)
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 1.5, height: 1.5)
                    .offset(
                        x: [width*0.2, -width*0.15, width*0.1, -width*0.25][index],
                        y: [-height*0.2, height*0.15, -height*0.1, height*0.25][index]
                    )
            }
        }
        .frame(maxWidth: width == 200 ? .infinity : width, maxHeight: height)
        .aspectRatio(contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Alternative Variations

struct DefaultRecipeImageView_Elegant: View {
    let width: CGFloat
    let height: CGFloat

    init(width: CGFloat = 150, height: CGFloat = 150) {
        self.width = width
        self.height = height
    }

    var body: some View {
        ZStack {
            // Elegant gradient
            LinearGradient(
                colors: [
                    Color(.systemTeal).opacity(0.7),
                    Color(.systemBlue).opacity(0.5),
                    Color(.systemIndigo).opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Geometric pattern
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }

                Image(systemName: "leaf.fill")
                    .font(.system(size: min(width, height) * 0.25, weight: .light))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 2)

                Text("Healthy")
                    .font(.system(size: min(width, height) * 0.07, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DefaultRecipeImageView_Warm: View {
    let width: CGFloat
    let height: CGFloat

    init(width: CGFloat = 150, height: CGFloat = 150) {
        self.width = width
        self.height = height
    }

    var body: some View {
        ZStack {
            // Warm gradient
            LinearGradient(
                colors: [
                    Color(.systemYellow).opacity(0.8),
                    Color(.systemOrange).opacity(0.7),
                    Color(.systemBrown).opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Food-themed design
            VStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: min(width, height) * 0.15, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2)

                Image(systemName: "fork.knife.circle")
                    .font(.system(size: min(width, height) * 0.2, weight: .light))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2)

                Text("Delicious")
                    .font(.system(size: min(width, height) * 0.08, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 1)
            }

            // Decorative circles
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .frame(width: width * 0.7, height: width * 0.7)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            DefaultRecipeImageView(width: 120, height: 120)
            DefaultRecipeImageView_Elegant(width: 120, height: 120)
            DefaultRecipeImageView_Warm(width: 120, height: 120)
        }

        Text("Default Recipe Image Variations")
            .font(.headline)
    }
    .padding()
}