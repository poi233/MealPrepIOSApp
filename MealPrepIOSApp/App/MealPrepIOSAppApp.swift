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
                    // Initialize stores after the app has fully loaded
                    Task {
                        // Small delay to ensure CoreData is fully initialized
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        await MainActor.run {
                            authStore.initialize()
                            // If user is already authenticated on app start, initialize meal plan data
                            if authStore.isAuthenticated {
                                mealPlanStore.initializeData()
                            }
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // Save meal plan data when app goes to background
                    print("📱 [App] App will resign active - saving meal plan data")
                    let saveResult = mealPlanStore.saveLocalMealPlan()
                    switch saveResult {
                    case .success():
                        print("✅ [App] Meal plan saved on background")
                    case .failure(let error):
                        print("❌ [App] Failed to save meal plan on background: \(error.localizedDescription)")
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    // Save meal plan data when app is about to terminate
                    print("📱 [App] App will terminate - saving meal plan data")
                    let saveResult = mealPlanStore.saveLocalMealPlan()
                    switch saveResult {
                    case .success():
                        print("✅ [App] Meal plan saved on termination")
                    case .failure(let error):
                        print("❌ [App] Failed to save meal plan on termination: \(error.localizedDescription)")
                    }
                }
        }
    }
}
