//
//  SharedComponents.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import SwiftUI

// MARK: - Loading View
struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Auto-refresh View Modifier

struct AutoRefreshViewModifier: ViewModifier {
    let action: () async -> Void
    @State private var hasAppeared = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if !hasAppeared {
                    hasAppeared = true
                    Task {
                        await action()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task {
                    await action()
                }
            }
    }
}

extension View {
    func autoRefresh(action: @escaping () async -> Void) -> some View {
        self.modifier(AutoRefreshViewModifier(action: action))
    }
}

// MARK: - Enhanced Filter Chip with Magic UI styling
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    ZStack {
                        if isSelected {
                            // Selected state with gradient
                            LinearGradient(
                                colors: [Color.primaryGreen, Color.primaryGreen.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            // Unselected state
                            Color(.systemBackground)
                        }
                    }
                )
                .foregroundColor(isSelected ? .white : .primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isSelected ? Color.clear : Color.primaryGreen.opacity(0.3),
                            lineWidth: 1
                        )
                )
                .cornerRadius(20)
                .shadow(
                    color: isSelected ? Color.primaryGreen.opacity(0.3) : Color.black.opacity(0.1),
                    radius: isSelected ? 8 : 2,
                    x: 0,
                    y: isSelected ? 4 : 1
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Enhanced Search Bar with Magic UI styling
struct SearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    @State private var isEditing = false
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isFocused ? .primaryGreen : .secondary)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                
                TextField("Search recipes, ingredients...", text: $text)
                    .font(.body)
                    .focused($isFocused)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onTapGesture {
                        isEditing = true
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            text = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isFocused ? Color.primaryGreen : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .shadow(
                color: isFocused ? Color.primaryGreen.opacity(0.2) : Color.black.opacity(0.05),
                radius: isFocused ? 8 : 2,
                x: 0,
                y: isFocused ? 4 : 1
            )
            
            if isEditing {
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        text = ""
                        isEditing = false
                        isFocused = false
                    }
                }
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primaryGreen)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEditing)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        .onChange(of: isFocused) { _, focused in
            isEditing = focused
        }
    }
}

// MARK: - Stat View
struct StatView: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(.primaryGreen)
                Text(value)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Enhanced Empty State View with Magic UI styling
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 24) {
                // Static icon with gradient
                Image(systemName: icon)
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.secondary, .secondary.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 12) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .primary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text(message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                if let actionTitle = actionTitle, let action = action {
                    StaticButton(actionTitle, action: action)
                        .padding(.top, 8)
                }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}



