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
                    // Top spacer - fixed height
                    Spacer()
                        .frame(height: 30)
                    
                    // Logo/Title - static, no animations or click interactions
                    VStack(spacing: 12) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.accentColor, .blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .accentColor.opacity(0.3), radius: 10)
                        
                        Text("MealPrep AI")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Your personal cooking companion")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Middle spacer
                    Spacer()
                        .frame(height: 15)
                    
                    // Login Form in Magic Card
                    MagicCard {
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Welcome back")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text("Sign in to your account")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(spacing: 16) {
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
                            
                            VStack(spacing: 12) {
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
                    .frame(maxWidth: 350)
                    
                    // Bottom spacer
                    Spacer()
                        .frame(height: 15)
                    
                    // Register Link
                    VStack(spacing: 12) {
                        HStack {
                            Rectangle()
                                .frame(height: 1)
                                .frame(minWidth: 20)
                                .foregroundColor(.secondary.opacity(0.3))
                            Text("or")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                            Rectangle()
                                .frame(height: 1)
                                .frame(minWidth: 20)
                                .foregroundColor(.secondary.opacity(0.3))
                        }
                        
                        RippleButton("Create new account", style: .outline) {
                            showingRegister = true
                        }
                        .frame(maxWidth: 350)
                    }
                    
                    // Bottom spacer
                    Spacer()
                        .frame(height: 30)
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