import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var userProfileStore: UserProfileStore
    
    var body: some View {
        NavigationView {
            List {
                // User Info Section
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Color(red: 77/255, green: 182/255, blue: 172/255))
                        
                        VStack(alignment: .leading) {
                            if let user = authStore.currentUser {
                                Text(user.fullDisplayName)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                // Profile Settings
                Section("Preferences") {
                    NavigationLink(destination: DietaryPreferencesView()) {
                        Label("Dietary Preferences", systemImage: "leaf")
                    }
                    
                    NavigationLink(destination: AllergiesView()) {
                        Label("Allergies", systemImage: "exclamationmark.triangle")
                    }
                    
                    NavigationLink(destination: CuisinePreferencesView()) {
                        Label("Cuisine Preferences", systemImage: "globe")
                    }
                }
                
                // App Settings
                Section("Settings") {
                    NavigationLink(destination: NotificationSettingsView()) {
                        Label("Notifications", systemImage: "bell")
                    }
                    
                    NavigationLink(destination: AboutView()) {
                        Label("About", systemImage: "info.circle")
                    }
                }
                
                // Logout
                Section {
                    Button(action: {
                        Task {
                            await authStore.logout()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                            Text("Logout")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Profile")
            .onAppear {
                userProfileStore.fetchProfile()
            }
        }
    }
}

// Placeholder views for navigation
struct DietaryPreferencesView: View {
    var body: some View {
        Text("Dietary Preferences")
            .navigationTitle("Dietary Preferences")
    }
}

struct AllergiesView: View {
    var body: some View {
        Text("Allergies")
            .navigationTitle("Allergies")
    }
}

struct CuisinePreferencesView: View {
    var body: some View {
        Text("Cuisine Preferences")
            .navigationTitle("Cuisine Preferences")
    }
}

struct NotificationSettingsView: View {
    var body: some View {
        Text("Notification Settings")
            .navigationTitle("Notifications")
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(red: 77/255, green: 182/255, blue: 172/255))
            
            Text("MealPrep AI")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("AI-powered meal planning made simple")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .navigationTitle("About")
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthStore())
        .environmentObject(UserProfileStore())
}