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
            if authStore.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onReceive(authStore.$sessionError) { sessionError in
            if sessionError != nil {
                // Session expired - this will automatically redirect to LoginView
                // because isAuthenticated becomes false when sessionError is set
            }
        }
        .alert("Session Expired", isPresented: .constant(authStore.sessionError != nil)) {
            Button("OK") {
                authStore.clearSessionError()
            }
        } message: {
            if let error = authStore.sessionError {
                Text(error)
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
