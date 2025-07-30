//
//  LoadingAnimations.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/30/25.
//  Enhanced loading animations for better UX
//

import SwiftUI

// MARK: - Template Saving Loading Animation

struct TemplateSavingLoader: View {
    let progress: Double // 0.0 to 1.0
    let statusText: String
    let currentStep: String
    
    @State private var rotation: Double = 0
    @State private var scale: Double = 1.0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        VStack(spacing: 24) {
            // Circular Progress Ring with Animated Center
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.primaryGreen, .primaryGreen.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90)) // Start from top
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                // Animated center icon
                ZStack {
                    // Pulsing background
                    Circle()
                        .fill(Color.primaryGreen.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .scaleEffect(scale)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: scale)
                    
                    // Rotating icon
                    Image(systemName: "folder.badge.plus")
                        .font(.title2)
                        .foregroundColor(.primaryGreen)
                        .rotationEffect(.degrees(rotation))
                        .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: rotation)
                }
            }
            
            // Status text with fade animation
            VStack(spacing: 8) {
                Text(statusText)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .opacity(opacity)
                    .animation(.easeInOut(duration: 0.3), value: opacity)
                
                Text(currentStep)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(opacity)
                    .animation(.easeInOut(duration: 0.3), value: opacity)
            }
            
            // Animated dots
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.primaryGreen)
                        .frame(width: 8, height: 8)
                        .scaleEffect(scale)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: scale
                        )
                }
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .onAppear {
            rotation = 360
            scale = 1.2
            opacity = 1.0
        }
    }
}

// MARK: - Simple Circular Progress

struct CircularProgress: View {
    let progress: Double // 0.0 to 1.0
    let size: CGFloat
    let lineWidth: CGFloat
    let accentColor: Color
    
    init(progress: Double, size: CGFloat = 40, lineWidth: CGFloat = 4, accentColor: Color = .primaryGreen) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.accentColor = accentColor
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
    }
}

// MARK: - Orbiting Circles Animation

struct OrbitingCircles: View {
    @State private var rotation: Double = 0
    let size: CGFloat
    let circleCount: Int
    let duration: Double
    
    init(size: CGFloat = 60, circleCount: Int = 3, duration: Double = 2.0) {
        self.size = size
        self.circleCount = circleCount
        self.duration = duration
    }
    
    var body: some View {
        ZStack {
            ForEach(0..<circleCount, id: \.self) { index in
                Circle()
                    .fill(Color.primaryGreen.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .offset(x: size / 2)
                    .rotationEffect(.degrees(rotation + Double(index) * (360.0 / Double(circleCount))))
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Particles Effect

struct ParticlesEffect: View {
    @State private var particles: [Particle] = []
    let particleCount: Int
    let bounds: CGRect
    
    init(particleCount: Int = 20, bounds: CGRect = CGRect(x: 0, y: 0, width: 200, height: 200)) {
        self.particleCount = particleCount
        self.bounds = bounds
    }
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                Circle()
                    .fill(Color.primaryGreen.opacity(particles[index].opacity))
                    .frame(width: particles[index].size, height: particles[index].size)
                    .position(particles[index].position)
                    .animation(.linear(duration: particles[index].duration), value: particles[index].position)
            }
        }
        .frame(width: bounds.width, height: bounds.height)
        .onAppear {
            generateParticles()
            startAnimation()
        }
    }
    
    private func generateParticles() {
        particles = (0..<particleCount).map { _ in
            Particle(
                position: CGPoint(
                    x: Double.random(in: 0...bounds.width),
                    y: Double.random(in: 0...bounds.height)
                ),
                size: Double.random(in: 2...6),
                opacity: Double.random(in: 0.3...0.8),
                duration: Double.random(in: 1...3)
            )
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            for index in particles.indices {
                withAnimation(.linear(duration: particles[index].duration)) {
                    particles[index].position = CGPoint(
                        x: Double.random(in: 0...bounds.width),
                        y: Double.random(in: 0...bounds.height)
                    )
                }
            }
        }
    }
}

struct Particle {
    var position: CGPoint
    let size: Double
    let opacity: Double
    let duration: Double
}

// MARK: - Loading States Enum

enum TemplateSavingState {
    case validating
    case creatingRecipes
    case savingTemplate
    case completed
    case error(String)
    
    var progress: Double {
        switch self {
        case .validating: return 0.25
        case .creatingRecipes: return 0.60
        case .savingTemplate: return 0.90
        case .completed: return 1.0
        case .error: return 0.0
        }
    }
    
    var statusText: String {
        switch self {
        case .validating: return "Validating Recipes"
        case .creatingRecipes: return "Creating Recipes"
        case .savingTemplate: return "Saving Template"
        case .completed: return "Template Saved!"
        case .error: return "Error Occurred"
        }
    }
    
    var currentStep: String {
        switch self {
        case .validating: return "Checking recipe database..."
        case .creatingRecipes: return "Creating missing recipes in backend..."
        case .savingTemplate: return "Finalizing template creation..."
        case .completed: return "Your template is ready to use!"
        case .error(let message): return message
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        TemplateSavingLoader(
            progress: 0.6,
            statusText: "Creating Recipes",
            currentStep: "Creating missing recipes in backend..."
        )
        
        CircularProgress(progress: 0.75)
        
        OrbitingCircles()
    }
    .padding()
}