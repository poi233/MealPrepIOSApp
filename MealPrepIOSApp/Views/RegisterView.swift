import SwiftUI

struct RegisterView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authStore: AuthStore
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    BlurFade(delay: 0.1) {
                        VStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 80))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.accentColor, .green, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .accentColor.opacity(0.3), radius: 10)
                            
                            Text("Join MealPrep AI")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Start your culinary journey today")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Registration Form in Magic Card
                    BlurFade(delay: 0.3) {
                        MagicCard {
                            VStack(spacing: 24) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Create your account")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("Fill in your details to get started")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                VStack(spacing: 20) {
                                    HStack(spacing: 12) {
                                        AnimatedTextField("First name", text: $firstName)
                                        AnimatedTextField("Last name", text: $lastName)
                                    }
                                    
                                    AnimatedTextField("Email", text: $email, keyboardType: .emailAddress)
                                        .textInputAutocapitalization(.never)
                                    
                                    AnimatedTextField("Password", text: $password, isSecure: true)
                                    
                                    AnimatedTextField("Confirm password", text: $confirmPassword, isSecure: true)
                                    
                                    // Error messages
                                    VStack(alignment: .leading, spacing: 8) {
                                        if let errorMessage = authStore.errorMessage {
                                            HStack {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                Text(errorMessage)
                                                    .font(.caption)
                                            }
                                            .foregroundColor(.red)
                                        }
                                        
                                        if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                                            HStack {
                                                Image(systemName: "xmark.circle.fill")
                                                Text("Passwords don't match")
                                                    .font(.caption)
                                            }
                                            .foregroundColor(.red)
                                        }
                                        
                                        if !password.isEmpty && password.count < 6 {
                                            HStack {
                                                Image(systemName: "info.circle.fill")
                                                Text("Password must be at least 6 characters")
                                                    .font(.caption)
                                            }
                                            .foregroundColor(.orange)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                VStack(spacing: 16) {
                                    ShimmerButton(
                                        "Create Account",
                                        isLoading: authStore.isLoading,
                                        disabled: !isFormValid
                                    ) {
                                        register()
                                    }
                                    
                                    Text("By signing up, you agree to our Terms of Service and Privacy Policy")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                    }
                    
                    // Back to login
                    BlurFade(delay: 0.5) {
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
                            
                            RippleButton("Already have an account?", style: .secondary) {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .navigationBarHidden(true)
            .background(
                // Gradient background
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color.green.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                // Close button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 24)
                        .padding(.top, 16)
                    }
                    Spacer()
                },
                alignment: .topTrailing
            )
        }
    }
    
    private var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && 
        !password.isEmpty && password == confirmPassword
    }
    
    private func register() {
        // Derive username and display name from the form inputs
        let username = email             // use the email as a unique username
        let displayName = "\(firstName) \(lastName)"
        Task {
            let registerData = RegisterData(
                username: username,
                email: email,
                password: password,
                displayName: displayName,
                dietaryPreferences: nil
            )
            
            await authStore.register(userData: registerData)
        }
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthStore())
}
