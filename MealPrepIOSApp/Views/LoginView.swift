import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authStore: AuthStore
    @State private var email = ""
    @State private var password = ""
    @State private var showingRegister = false
    @State private var loginTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
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
                                    colors: [.primaryGreen, .secondaryGreen, .tertiaryGreen],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .primaryGreen.opacity(0.3), radius: 10)
                        
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
                    
                    // Login Form in Fixed Size Card
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
                            StaticTextField("Email", text: $email, keyboardType: .emailAddress)
                                .textInputAutocapitalization(.never)
                            
                            StaticTextField("Password", text: $password, isSecure: true)
                            
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
                            StaticButton(
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
                            .foregroundColor(.primaryGreen)
                        }
                    }
                    .frame(width: 350, height: 380)
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    
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
                        
                        StaticOutlineButton("Create new account", style: .outline) {
                            showingRegister = true
                        }
                        .frame(width: 350)
                    }
                    
                    // Bottom spacer
                    Spacer()
                        .frame(height: 30)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationBarHidden(true)
            .background(
                // Gradient background
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color.primaryGreen.opacity(0.05)
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