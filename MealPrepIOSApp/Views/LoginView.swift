import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authStore: AuthStore
    @State private var email = ""
    @State private var password = ""
    @State private var showingRegister = false
    @State private var loginTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 50)
                    
                    // Logo/Title with sparkle effect
                    BlurFade(delay: 0.2) {
                        VStack(spacing: 16) {
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.system(size: 100))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.accentColor, .blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .accentColor.opacity(0.3), radius: 10)
                            
                            SparklesText("MealPrep AI", font: .title)
                            
                            Text("Your personal cooking companion")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Login Form in Magic Card
                    BlurFade(delay: 0.4) {
                        MagicCard {
                            VStack(spacing: 24) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Welcome back")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("Sign in to your account")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                VStack(spacing: 20) {
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
                                
                                VStack(spacing: 16) {
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
                    }
                    
                    // Register Link
                    BlurFade(delay: 0.6) {
                        VStack(spacing: 16) {
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
                        }
                    }
                    
                    Spacer(minLength: 50)
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