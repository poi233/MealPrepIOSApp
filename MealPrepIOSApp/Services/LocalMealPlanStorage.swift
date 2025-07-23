//
//  LocalMealPlanStorage.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/22/25.
//

import Foundation

class LocalMealPlanStorage {
    static let shared = LocalMealPlanStorage()
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    private let weeklyMealPlanKey = "weeklyMealPlan"
    
    // Save weekly meal plan to local storage
    func saveWeeklyMealPlan(_ weeklyGrid: WeeklyMealGrid) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(weeklyGrid)
            userDefaults.set(data, forKey: weeklyMealPlanKey)
            print("✅ Saved meal plan locally")
        } catch {
            print("❌ Failed to save meal plan locally: \(error)")
        }
    }
    
    // Load weekly meal plan from local storage
    func loadWeeklyMealPlan() -> WeeklyMealGrid? {
        guard let data = userDefaults.data(forKey: weeklyMealPlanKey) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let weeklyGrid = try decoder.decode(WeeklyMealGrid.self, from: data)
            print("✅ Loaded meal plan from local storage")
            return weeklyGrid
        } catch {
            print("❌ Failed to load meal plan from local storage: \(error)")
            return nil
        }
    }
    
    // Clear local meal plan
    func clearLocalMealPlan() {
        userDefaults.removeObject(forKey: weeklyMealPlanKey)
        print("✅ Cleared local meal plan")
    }
}