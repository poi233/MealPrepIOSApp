import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var userProfileStore: UserProfileStore

    var body: some View {
        NavigationView {
            List {
                // User Info Section
                Section {
                    if let user = authStore.currentUser {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(Color(red: 77/255, green: 182/255, blue: 172/255))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.fullDisplayName)
                                    .font(.headline)
                                    .fontWeight(.semibold)

                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text("@\(user.username)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("Member since \(user.createdAt, style: .date)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 12)

                        // Display dietary preferences if available
                        if let dietaryPrefs = user.dietaryPreferences {
                            VStack(alignment: .leading, spacing: 8) {
                                if let dietType = dietaryPrefs.dietType {
                                    HStack {
                                        Image(systemName: "leaf.fill")
                                            .foregroundColor(.green)
                                        Text("Diet: \(dietType.capitalized)")
                                            .font(.subheadline)
                                    }
                                }

                                if let calorieTarget = dietaryPrefs.calorieTarget {
                                    HStack {
                                        Image(systemName: "flame.fill")
                                            .foregroundColor(.orange)
                                        Text("Daily Calories: \(calorieTarget)")
                                            .font(.subheadline)
                                    }
                                }

                                if let allergies = dietaryPrefs.allergies, !allergies.isEmpty {
                                    HStack(alignment: .top) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                        VStack(alignment: .leading) {
                                            Text("Allergies:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text(allergies.joined(separator: ", "))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }

                                if let dislikes = dietaryPrefs.dislikes, !dislikes.isEmpty {
                                    HStack(alignment: .top) {
                                        Image(systemName: "hand.raised.fill")
                                            .foregroundColor(.yellow)
                                        VStack(alignment: .leading) {
                                            Text("Avoids:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text(dislikes.joined(separator: ", "))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                    } else {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading profile...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 20)
                    }
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