import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authStore: AuthStore

    var body: some View {
        NavigationView {
            List {
                Section {
                    if let user = authStore.currentUser {
                        userInfoSection(user)
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

                Section("Preferences") {
                    NavigationLink(destination: DietaryPreferencesView().environmentObject(authStore)) {
                        Label("Dietary Preferences", systemImage: "leaf")
                    }
                }

                Section("Settings") {
                    NavigationLink(destination: AboutView()) {
                        Label("About", systemImage: "info.circle")
                    }
                }

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
        }
    }

    @ViewBuilder
    private func userInfoSection(_ user: User) -> some View {
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

        if let dietaryPrefs = user.dietaryPreferences,
           dietaryPrefs.dietType != nil || dietaryPrefs.calorieTarget != nil || !(dietaryPrefs.allergies ?? []).isEmpty || !(dietaryPrefs.dislikes ?? []).isEmpty {
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
                    profileListRow(icon: "exclamationmark.triangle.fill", color: .red, title: "Allergies", values: allergies)
                }

                if let dislikes = dietaryPrefs.dislikes, !dislikes.isEmpty {
                    profileListRow(icon: "hand.raised.fill", color: .yellow, title: "Avoids", values: dislikes)
                }
            }
            .padding(.top, 8)
        }
    }

    private func profileListRow(icon: String, color: Color, title: String, values: [String]) -> some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(color)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(values.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct DietaryPreferencesView: View {
    @EnvironmentObject var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDietType = ""
    @State private var calorieTarget = ""
    @State private var allergies = ""
    @State private var dislikes = ""
    @State private var isSaving = false
    @State private var saveError: String?

    private var dietOptions: [String] {
        [""] + DietType.allCases.map(\.rawValue)
    }

    var body: some View {
        Form {
            Section("Diet") {
                Picker("Diet Type", selection: $selectedDietType) {
                    Text("No preference").tag("")
                    ForEach(DietType.allCases, id: \.rawValue) { dietType in
                        Text(dietType.displayName).tag(dietType.rawValue)
                    }
                }

                TextField("Daily calorie target", text: $calorieTarget)
                    .keyboardType(.numberPad)
            }

            Section("Restrictions") {
                TextField("Allergies", text: $allergies, prompt: Text("nuts, shellfish"))
                    .textInputAutocapitalization(.never)

                TextField("Foods to avoid", text: $dislikes, prompt: Text("mushrooms, cilantro"))
                    .textInputAutocapitalization(.never)
            }

            if let saveError {
                Section {
                    Label(saveError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Dietary Preferences")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isSaving ? "Saving" : "Save") {
                    Task {
                        await savePreferences()
                    }
                }
                .disabled(isSaving)
            }
        }
        .onAppear(perform: loadCurrentPreferences)
    }

    private func loadCurrentPreferences() {
        guard let preferences = authStore.currentUser?.dietaryPreferences else { return }
        selectedDietType = preferences.dietType ?? ""
        calorieTarget = preferences.calorieTarget.map(String.init) ?? ""
        allergies = (preferences.allergies ?? []).joined(separator: ", ")
        dislikes = (preferences.dislikes ?? []).joined(separator: ", ")
    }

    private func savePreferences() async {
        isSaving = true
        saveError = nil

        let trimmedCalories = calorieTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedCalories = trimmedCalories.isEmpty ? nil : Int(trimmedCalories)

        if parsedCalories == nil && !trimmedCalories.isEmpty {
            saveError = "Calorie target must be a whole number."
            isSaving = false
            return
        }

        let preferences = DietaryPreferences(
            dietType: selectedDietType.isEmpty ? nil : selectedDietType,
            allergies: parseCommaSeparated(allergies),
            dislikes: parseCommaSeparated(dislikes),
            calorieTarget: parsedCalories
        )

        let success = await authStore.updateProfile(
            updates: ProfileUpdates(
                displayName: authStore.currentUser?.displayName,
                dietaryPreferences: preferences,
                email: nil
            )
        )

        isSaving = false

        if success {
            dismiss()
        } else {
            saveError = "Failed to save preferences. Please try again."
        }
    }

    private func parseCommaSeparated(_ value: String) -> [String]? {
        let values = value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return values.isEmpty ? nil : values
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
}
