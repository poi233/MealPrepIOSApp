//
//  MagicUIComponents.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/21/25.
//  Inspired by Magic UI Design System
//

import SwiftUI

// MARK: - Shimmer Button
struct ShimmerButton: View {
    let title: String
    let action: () -> Void
    let isLoading: Bool
    let disabled: Bool
    
    @State private var shimmerOffset: CGFloat = -200
    
    init(_ title: String, isLoading: Bool = false, disabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.action = action
        self.isLoading = isLoading
        self.disabled = disabled
    }
    
    var body: some View {
        Button(action: disabled ? {} : action) {
            ZStack {
                // Background with gradient
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: disabled ? [Color.gray.opacity(0.3)] : [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 50)
                
                // Shimmer effect
                if !disabled && !isLoading {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.white.opacity(0.3), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 100)
                        .offset(x: shimmerOffset)
                        .onAppear {
                            withAnimation(
                                Animation.linear(duration: 2.0)
                                    .repeatForever(autoreverses: false)
                            ) {
                                shimmerOffset = 300
                            }
                        }
                }
                
                // Content
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .disabled(disabled || isLoading)
        .animation(.easeInOut(duration: 0.2), value: disabled)
    }
}

// MARK: - Ripple Button
struct RippleButton: View {
    let title: String
    let action: () -> Void
    let style: RippleButtonStyle
    
    @State private var ripples: [RippleEffect] = []
    
    enum RippleButtonStyle {
        case primary, secondary, outline
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .accentColor
            case .secondary: return Color(.secondarySystemBackground)
            case .outline: return .clear
            }
        }
        
        var borderColor: Color {
            switch self {
            case .primary: return .clear
            case .secondary: return .clear
            case .outline: return .accentColor
            }
        }
        
        var textColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .primary
            case .outline: return .accentColor
            }
        }
    }
    
    struct RippleEffect: Identifiable {
        let id = UUID()
        let position: CGPoint
        let startTime: Date
    }
    
    init(_ title: String, style: RippleButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: {}) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(style.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(style.borderColor, lineWidth: style == .outline ? 1 : 0)
                    )
                    .frame(height: 44)
                
                // Ripple effects
                ForEach(ripples) { ripple in
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .position(ripple.position)
                        .scaleEffect(CGSize(width: 3, height: 3))
                        .opacity(0)
                        .animation(.easeOut(duration: 0.6), value: ripples.count)
                }
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(style.textColor)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    createRipple(at: value.location)
                    action()
                }
        )
    }
    
    private func createRipple(at location: CGPoint) {
        let ripple = RippleEffect(position: location, startTime: Date())
        ripples.append(ripple)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            ripples.removeAll { $0.id == ripple.id }
        }
    }
}

// MARK: - Magic Card
struct MagicCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    
    init(cornerRadius: CGFloat = 16, shadowRadius: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }
    
    var body: some View {
        ZStack {
            // Background with gradient - static, no hover effects
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            Color(.systemBackground).opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.accentColor.opacity(0.1))
                )
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: shadowRadius,
                    x: 0,
                    y: 4
                )
            
            content
                .padding()
        }
    }
}

// MARK: - Animated Text Field
struct AnimatedTextField: View {
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let isSecure: Bool
    
    @FocusState private var isFocused: Bool
    @State private var animateLabel = false
    
    init(_ placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default, isSecure: Bool = false) {
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
        self.isSecure = isSecure
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .stroke(
                    isFocused ? Color.accentColor : Color.clear,
                    lineWidth: isFocused ? 2 : 0
                )
                .frame(height: 56)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
            
            VStack(alignment: .leading, spacing: 4) {
                // Animated label
                Text(placeholder)
                    .font(animateLabel ? .caption : .body)
                    .foregroundColor(isFocused ? .accentColor : .secondary)
                    .offset(y: animateLabel ? -8 : 0)
                    .scaleEffect(animateLabel ? 0.9 : 1.0, anchor: .leading)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: animateLabel)
                
                // Text field
                Group {
                    if isSecure {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                            .keyboardType(keyboardType)
                    }
                }
                .font(.body)
                .focused($isFocused)
                .onChange(of: isFocused) { _, focused in
                    animateLabel = focused || !text.isEmpty
                }
                .onChange(of: text) { _, newText in
                    animateLabel = !newText.isEmpty || isFocused
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, animateLabel ? 12 : 0)
        }
        .onAppear {
            animateLabel = !text.isEmpty
        }
    }
}

// MARK: - Blur Fade Animation
struct BlurFade<Content: View>: View {
    let content: Content
    let delay: Double
    
    @State private var opacity: Double = 0
    @State private var blur: CGFloat = 10
    @State private var scale: CGFloat = 0.8
    
    init(delay: Double = 0, @ViewBuilder content: () -> Content) {
        self.delay = delay
        self.content = content()
    }
    
    var body: some View {
        content
            .opacity(opacity)
            .blur(radius: blur)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .spring(response: 0.8, dampingFraction: 0.7)
                    .delay(delay)
                ) {
                    opacity = 1
                    blur = 0
                    scale = 1.0
                }
            }
    }
}

// MARK: - Sparkles Text
struct SparklesText: View {
    let text: String
    let font: Font
    
    @State private var sparkles: [SparkleEffect] = []
    
    struct SparkleEffect: Identifiable {
        let id = UUID()
        let position: CGPoint
        let delay: Double
    }
    
    init(_ text: String, font: Font = .title) {
        self.text = text
        self.font = font
    }
    
    var body: some View {
        ZStack {
            Text(text)
                .font(font)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentColor, .blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            ForEach(sparkles) { sparkle in
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .position(sparkle.position)
                    .opacity(0)
                    .scaleEffect(0.5)
                    .animation(
                        .easeInOut(duration: 1.0)
                        .delay(sparkle.delay)
                        .repeatForever(autoreverses: true),
                        value: sparkles.count
                    )
            }
        }
        .onAppear {
            generateSparkles()
        }
    }
    
    private func generateSparkles() {
        for i in 0..<5 {
            let sparkle = SparkleEffect(
                position: CGPoint(
                    x: CGFloat.random(in: 0...200),
                    y: CGFloat.random(in: 0...50)
                ),
                delay: Double(i) * 0.2
            )
            sparkles.append(sparkle)
        }
    }
}

// MARK: - Enhanced Recipe Card
struct EnhancedRecipeCard: View {
    let recipe: Recipe
    let style: RecipeCardStyle
    let onTap: () -> Void
    let onFavoriteToggle: () -> Void
    
    @State private var isFavorite = false
    @State private var isHovered = false
    
    enum RecipeCardStyle {
        case standard, compact, featured
        
        var cardHeight: CGFloat {
            switch self {
            case .standard: return 280
            case .compact: return 240
            case .featured: return 320
            }
        }
        
        var imageHeight: CGFloat {
            switch self {
            case .standard: return 160
            case .compact: return 120
            case .featured: return 200
            }
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background with blur effect
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.1), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blur(radius: isHovered ? 20 : 0)
                    )
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: isHovered ? 15 : 8,
                        x: 0,
                        y: isHovered ? 8 : 4
                    )
                
                // Border gradient
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: isHovered ? 
                                [Color.accentColor.opacity(0.3), Color.blue.opacity(0.3)] : 
                                [Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 2 : 0
                    )
                
                VStack(alignment: .leading, spacing: 0) {
                    // Recipe Image with overlay
                    ZStack {
                        AsyncImage(url: URL(string: recipe.imageUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.title)
                                        .foregroundColor(.gray.opacity(0.6))
                                )
                        }
                        .frame(height: style.imageHeight)
                        .clipped()
                        
                        // Gradient overlay
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        
                        // Favorite button
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: onFavoriteToggle) {
                                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                                        .font(.title2)
                                        .foregroundColor(isFavorite ? .red : .white)
                                        .background(
                                            Circle()
                                                .fill(Color.black.opacity(0.3))
                                                .blur(radius: 4)
                                        )
                                        .scaleEffect(isHovered ? 1.1 : 1.0)
                                }
                                .padding(.trailing, 16)
                                .padding(.top, 16)
                            }
                            Spacer()
                        }
                        
                        // Difficulty badge
                        VStack {
                            HStack {
                                DifficultyBadge(difficulty: recipe.difficulty)
                                    .padding(.leading, 16)
                                    .padding(.top, 16)
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                    .cornerRadius(16, corners: [.topLeft, .topRight])
                    
                    // Recipe Info
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.name)
                                .font(style == .compact ? .headline : .title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            if style != .compact {
                                Text(recipe.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        
                        // Stats row
                        HStack(spacing: 16) {
                            StatItem(
                                icon: "clock",
                                value: "\(recipe.totalTime)m",
                                color: .blue
                            )
                            
                            if style != .compact {
                                StatItem(
                                    icon: "star.fill",
                                    value: String(format: "%.1f", recipe.avgRating),
                                    color: .yellow
                                )
                            }
                            
                            Spacer()
                        }
                        
                        // Tags
                        if !recipe.tags.isEmpty && style != .compact {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(recipe.tags.prefix(3), id: \.self) { tag in
                                        TagChip(tag: tag)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .frame(height: style.cardHeight)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isHovered = true
                }
                .onEnded { _ in
                    isHovered = false
                }
        )
    }
}

// MARK: - Supporting Components
struct DifficultyBadge: View {
    let difficulty: Difficulty
    
    var badgeColor: Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
    
    var body: some View {
        Text(difficulty.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(badgeColor)
            )
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

struct TagChip: View {
    let tag: String
    
    var body: some View {
        Text(tag)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.1))
            )
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview Helpers
#Preview("Shimmer Button") {
    VStack(spacing: 20) {
        ShimmerButton("Login") {}
        ShimmerButton("Loading", isLoading: true) {}
        ShimmerButton("Disabled", disabled: true) {}
    }
    .padding()
}

#Preview("Magic Card") {
    MagicCard {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Premium Feature")
                    .font(.headline)
            }
            
            Text("This is a magic card with beautiful hover effects and gradient borders.")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    .padding()
}

#Preview("Animated Text Field") {
    VStack(spacing: 20) {
        AnimatedTextField("Email", text: .constant(""))
        AnimatedTextField("Password", text: .constant(""), isSecure: true)
    }
    .padding()
}