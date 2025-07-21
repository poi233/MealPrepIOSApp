//
//  MealPrepIOSAppApp.swift
//  MealPrepIOSApp
//
//  Created by PuYihao on 7/20/25.
//

import SwiftUI

@main
struct MealPrepIOSAppApp: App {
    @StateObject private var authStore = AuthStore()
    @StateObject private var recipeStore = RecipeStore()
    @StateObject private var mealPlanStore = MealPlanStore()
    @StateObject private var favoritesStore = FavoritesStore()
    @StateObject private var userProfileStore = UserProfileStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authStore)
                .environmentObject(recipeStore)
                .environmentObject(mealPlanStore)
                .environmentObject(favoritesStore)
                .environmentObject(userProfileStore)
                .onAppear {
                    authStore.checkAuthenticationStatus()
                }
        }
    }
}
