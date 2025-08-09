//
//  NotificationComponents.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/21/25.
//

import SwiftUI

// MARK: - Error Alert
struct ErrorAlert: ViewModifier {
    @ObservedObject var errorHandler: ErrorHandler

    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $errorHandler.isShowingError) {
                if let error = errorHandler.currentError {
                    if error.isRetryable {
                        Button("Retry") {
                            // Retry action would be handled by the calling context
                            errorHandler.clearError()
                        }
                    }

                    Button("OK") {
                        errorHandler.clearError()
                    }
                }
            } message: {
                if let error = errorHandler.currentError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error.localizedDescription ?? "Unknown error")

                        if let suggestion = error.recoverySuggestion {
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
    }
}

// MARK: - Notification Toast
struct NotificationToast: View {
    let notification: AppNotification
    let onDismiss: () -> Void

    @State private var offset: CGFloat = -100
    @State private var opacity: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notification.type.icon)
                .font(.title2)
                .foregroundColor(notification.type.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(notification.message)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(notification.type.color.opacity(0.3), lineWidth: 1)
        )
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                offset = 0
                opacity = 1
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height < -50 {
                        dismissWithAnimation()
                    }
                }
        )
    }

    private func dismissWithAnimation() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = -100
            opacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Notification Overlay
struct NotificationOverlay: View {
    @ObservedObject var errorHandler: ErrorHandler

    var body: some View {
        VStack(spacing: 8) {
            ForEach(errorHandler.notifications) { notification in
                NotificationToast(notification: notification) {
                    errorHandler.dismissNotification(notification)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: errorHandler.notifications.count)
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    let isLoading: Bool
    let message: String

    init(isLoading: Bool, message: String = "Loading...") {
        self.isLoading = isLoading
        self.message = message
    }

    var body: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)

                    Text(message)
                        .font(.body)
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.8))
                )
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: isLoading)
        }
    }
}

// MARK: - Offline Banner
struct OfflineBanner: View {
    let isOffline: Bool

    var body: some View {
        if isOffline {
            HStack {
                Image(systemName: "wifi.slash")
                    .font(.caption)
                    .foregroundColor(.white)

                Text("You're offline. Some features may be limited.")
                    .font(.caption)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange)
            .transition(.move(edge: .top))
            .animation(.easeInOut(duration: 0.3), value: isOffline)
        }
    }
}

// MARK: - View Extensions
extension View {
    func errorAlert() -> some View {
        modifier(ErrorAlert(errorHandler: ErrorHandler.shared))
    }

    func notificationOverlay() -> some View {
        overlay(
            NotificationOverlay(errorHandler: ErrorHandler.shared),
            alignment: .top
        )
    }

    func loadingOverlay(isLoading: Bool, message: String = "Loading...") -> some View {
        overlay(
            LoadingOverlay(isLoading: isLoading, message: message)
        )
    }

    func offlineBanner(isOffline: Bool) -> some View {
        VStack(spacing: 0) {
            OfflineBanner(isOffline: isOffline)
            self
        }
    }
}

// MARK: - Preview Helpers
#Preview("Notification Toast") {
    VStack(spacing: 16) {
        NotificationToast(notification: .success("Recipe saved successfully!")) {}
        NotificationToast(notification: .error(AppError(message: "Network connection lost"))) {}
        NotificationToast(notification: .warning("Please check your internet connection")) {}
        NotificationToast(notification: .info("Syncing recipes...")) {}
    }
    .padding()
    .background(Color(.systemGray6))
}

#Preview("Loading Overlay") {
    Rectangle()
        .fill(Color.blue)
        .frame(height: 200)
        .loadingOverlay(isLoading: true, message: "Saving recipe...")
}

#Preview("Offline Banner") {
    VStack {
        OfflineBanner(isOffline: true)
        Rectangle()
            .fill(Color.blue)
            .frame(height: 200)
    }
}