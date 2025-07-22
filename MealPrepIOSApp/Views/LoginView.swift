import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authStore: AuthStore
    @State private var email = ""
    @State private var password = ""
    @State private var showingRegister = false
    @State private var loginTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Top spacer - adaptive based on screen height
                    Spacer()
                        .frame(minHeight: geometry.size.height * 0.05, maxHeight: geometry.size.height * 0.1)
                    
                    // Logo/Title - static, no animations or click interactions
                    VStack(spacing: geometry.size.height > 700 ? 16 : 12) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: geometry.size.height > 700 ? 100 : 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.accentColor, .blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .accentColor.opacity(0.3), radius: 10)
                        
                        Text("MealPrep AI")
                            .font(geometry.size.height > 700 ? .title : .title2)
                            .fontWeight(.bold)
                        
                        Text("Your personal cooking companion")
                            .font(geometry.size.height > 700 ? .subheadline : .caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Middle spacer
                    Spacer()
                        .frame(minHeight: geometry.size.height * 0.02, maxHeight: geometry.size.height * 0.05)
                    
                    // Login Form in Magic Card
                    MagicCard {
                        VStack(spacing: geometry.size.height > 700 ? 24 : 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Welcome back")
                                    .font(geometry.size.height > 700 ? .title2 : .title3)
                                    .fontWeight(.bold)
                                Text("Sign in to your account")
                                    .font(geometry.size.height > 700 ? .subheadline : .caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(spacing: geometry.size.height > 700 ? 20 : 16) {
                                AnimatedTextField("Email", text: $email, keyboardType: .emailAddress)
                                    .textInputAutocapitalization(.never)
                                
                                AnimatedTextField("Password", text: $password, isSecure: true)
                                
                                if let errorMessage = authStore.errorMessage {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                        Text(errorMessage)
                                            .font(.caption)
                                    }
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            
                            VStack(spacing: geometry.size.height > 700 ? 16 : 12) {
                                ShimmerButton(
                                    "Sign In",
                                    isLoading: authStore.isLoading,
                                    disabled: email.isEmpty || password.isEmpty || loginTask != nil
                                ) {
                                    // Cancel any existing login task
                                    loginTask?.cancel()
                                    
                                    loginTask = Task { @MainActor in
                                        await authStore.login(email: email, password: password)
                                        loginTask = nil
                                    }
                                }
                                
                                Button("Forgot password?") {
                                    // TODO: Implement forgot password
                                }
                                .font(.caption)
                                .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .frame(maxWidth: min(geometry.size.width - 48, 400))
                    
                    // Bottom spacer
                    Spacer()
                        .frame(minHeight: geometry.size.height * 0.02, maxHeight: geometry.size.height * 0.04)
                    
                    // Register Link
                    VStack(spacing: geometry.size.height > 700 ? 16 : 12) {
                        HStack {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.secondary.opacity(0.3))
                            Text("or")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.secondary.opacity(0.3))
                        }
                        
                        RippleButton("Create new account", style: .outline) {
                            showingRegister = true
                        }
                        .frame(maxWidth: min(geometry.size.width - 48, 400))
                    }
                    
                    // Bottom spacer
                    Spacer()
                        .frame(minHeight: geometry.size.height * 0.05, maxHeight: geometry.size.height * 0.1)
                }
                .padding(.horizontal, 24)
            }
            .navigationBarHidden(true)
            .background(
                // Gradient background
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color.accentColor.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .sheet(isPresented: $showingRegister) {
                RegisterView()
            }
            .onDisappear {
                // Cancel any ongoing login task when view disappears
                loginTask?.cancel()
                loginTask = nil
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthStore())
}