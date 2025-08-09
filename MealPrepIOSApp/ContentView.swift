//
//  ContentView.swift
//  MealPrepIOSApp
//
//  Created by PuYihao on 7/20/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authStore: AuthStore

    var body: some View {
        Group {
            if authStore.isInitializing {
                // Show loading screen while checking authentication status
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)

                    Text("Loading...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else if authStore.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onReceive(authStore.$sessionError) { sessionError in
            if sessionError != nil {
                // Session expired - automatically clear the error and redirect to LoginView
                // The redirect happens automatically because isAuthenticated becomes false
                authStore.clearSessionError()
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: Int = 0 // Default to MealPlan tab (now index 0)

    var body: some View {
        TabView(selection: $selectedTab) {
            MealPlanView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Meal Plan")
                }
                .tag(0)

            RecipesView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("Recipes")
                }
                .tag(1)

            FavoritesView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Favorites")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(3)
        }
        .accentColor(Color(red: 77/255, green: 182/255, blue: 172/255)) // Teal color
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthStore())
}
