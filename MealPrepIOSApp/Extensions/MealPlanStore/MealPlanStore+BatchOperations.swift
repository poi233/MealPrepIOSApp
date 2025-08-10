//
//  MealPlanStore+BatchOperations.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 8/9/25.
//  Batch operations implementation for meal plan management.
//

import Foundation
import SwiftUI

// MARK: - Batch Operations Extension
extension MealPlanStore {
    
    // MARK: - Copy from Last Week
    
    func copyMealsFromLastWeek() async -> BatchOperationResult {
        // Calculate last week's date
        let calendar = Calendar.current
        let lastWeekStartDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedWeekStartDate) ?? selectedWeekStartDate
        
        do {
            // Try to find a meal plan from last week
            let lastWeekGrid = await loadWeeklyGridFromCache(for: lastWeekStartDate)
            
            if lastWeekGrid.dailyMeals.allSatisfy({ $0.breakfast.isEmpty && $0.lunch.isEmpty && $0.dinner.isEmpty }) {
                // No meals found from last week
                return BatchOperationResult(
                    isSuccess: false,
                    title: "No Meals to Copy",
                    message: "No meals were found for the previous week."
                )
            }
            
            // Copy meals to current week
            weeklyGrid = lastWeekGrid
            
            // Save to cache
            _ = localStorageService.saveMealPlan(weeklyGrid)
            
            // Try to sync to backend if there's an active meal plan (optional)
            if let activePlan = activeMealPlan {
                do {
                    try await mealPlanService.syncWeeklyGridToBackend(mealPlanId: activePlan.id, weeklyGrid: weeklyGrid)
                } catch {
                    print("⚠️ [BatchOperations] Backend sync failed, continuing with local operation: \(error)")
                    // Continue without backend sync - local operation succeeded
                }
            }
            
            let copiedMealsCount = countTotalMeals(in: lastWeekGrid)
            
            return BatchOperationResult(
                isSuccess: true,
                title: "Meals Copied Successfully",
                message: "Copied \(copiedMealsCount) meals from last week to current week."
            )
            
        } catch {
            print("❌ [BatchOperations] Error copying from last week: \(error)")
            return BatchOperationResult(
                isSuccess: false,
                title: "Copy Failed",
                message: "Failed to copy meals from last week: \(error.localizedDescription)"
            )
        }
    }
    
    // MARK: - Clear All Meals
    
    func clearAllMealsForWeek() async -> BatchOperationResult {
        let previousMealsCount = countTotalMeals(in: weeklyGrid)
        
        // Clear the weekly grid
        weeklyGrid = WeeklyMealGrid()
        
        do {
            // Save empty grid to cache
            _ = localStorageService.saveMealPlan(weeklyGrid)
            
            // Try to sync to backend if there's an active meal plan (optional)
            if let activePlan = activeMealPlan {
                do {
                    try await mealPlanService.syncWeeklyGridToBackend(mealPlanId: activePlan.id, weeklyGrid: weeklyGrid)
                } catch {
                    print("⚠️ [BatchOperations] Backend sync failed, continuing with local operation: \(error)")
                    // Continue without backend sync - local operation succeeded
                }
            }
            
            return BatchOperationResult(
                isSuccess: true,
                title: "All Meals Cleared",
                message: "Removed \(previousMealsCount) meals from this week."
            )
            
        } catch {
            print("❌ [BatchOperations] Error clearing meals: \(error)")
            return BatchOperationResult(
                isSuccess: false,
                title: "Clear Failed",
                message: "Failed to clear all meals: \(error.localizedDescription)"
            )
        }
    }
    
    // MARK: - Duplicate to Next Week
    
    func duplicateWeekToNextWeek() async -> BatchOperationResult {
        let currentMealsCount = countTotalMeals(in: weeklyGrid)
        
        if currentMealsCount == 0 {
            return BatchOperationResult(
                isSuccess: false,
                title: "No Meals to Duplicate",
                message: "Current week has no meals to copy to next week."
            )
        }
        
        let calendar = Calendar.current
        let nextWeekStartDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedWeekStartDate) ?? selectedWeekStartDate
        
        do {
            // Create a copy of current weekly grid for next week
            var nextWeekGrid = WeeklyMealGrid()
            
            // Update dates for next week while copying meals
            for (index, currentDayMeal) in weeklyGrid.dailyMeals.enumerated() {
                if index < nextWeekGrid.dailyMeals.count {
                    // Copy meals but update the date
                    let nextWeekDate = calendar.date(byAdding: .day, value: 7, to: currentDayMeal.date) ?? currentDayMeal.date
                    nextWeekGrid.dailyMeals[index] = DailyMealSlots(day: currentDayMeal.day, date: nextWeekDate)
                    nextWeekGrid.dailyMeals[index].breakfast = currentDayMeal.breakfast
                    nextWeekGrid.dailyMeals[index].lunch = currentDayMeal.lunch
                    nextWeekGrid.dailyMeals[index].dinner = currentDayMeal.dinner
                }
            }
            
            // Save the next week grid to local storage
            // Since the storage service uses normalized dates, this should work correctly
            let normalizedNextWeekStart = localStorageService.normalizeWeekStartDate(nextWeekStartDate)
            
            // Temporarily switch context to save next week's data
            let originalGrid = weeklyGrid
            let originalSelectedDate = selectedWeekStartDate
            
            weeklyGrid = nextWeekGrid
            selectedWeekStartDate = normalizedNextWeekStart
            
            // Save to local storage for next week
            let saveResult = localStorageService.saveMealPlan(nextWeekGrid)
            
            // Restore original context
            weeklyGrid = originalGrid
            selectedWeekStartDate = originalSelectedDate
            
            switch saveResult {
            case .success():
                // Try to sync to backend if possible (optional)
                do {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "MMM d"
                    
                    let request = CreateMealPlanRequest(
                        name: "Week of \(dateFormatter.string(from: nextWeekStartDate))",
                        description: "Duplicated from previous week",
                        startDate: nextWeekStartDate,
                        endDate: calendar.date(byAdding: .day, value: 6, to: nextWeekStartDate) ?? nextWeekStartDate,
                        items: nil,
                        preferences: MealPlanPreferences(
                            targetCalories: nil,
                            dietaryRestrictions: nil,
                            excludeIngredients: nil,
                            cuisinePreferences: nil,
                            mealTypes: MealType.allCases,
                            maxPrepTime: nil,
                            budgetLevel: nil
                        )
                    )
                    
                    let newMealPlan = try await mealPlanService.createMealPlan(request)
                    try await mealPlanService.syncWeeklyGridToBackend(mealPlanId: newMealPlan.id, weeklyGrid: nextWeekGrid)
                    
                    return BatchOperationResult(
                        isSuccess: true,
                        title: "Week Duplicated Successfully",
                        message: "Copied \(currentMealsCount) meals to next week with backend sync."
                    )
                } catch {
                    print("⚠️ [BatchOperations] Backend sync failed, but local duplication succeeded: \(error)")
                    return BatchOperationResult(
                        isSuccess: true,
                        title: "Week Duplicated (Local)",
                        message: "Copied \(currentMealsCount) meals to next week locally."
                    )
                }
            case .failure(let error):
                return BatchOperationResult(
                    isSuccess: false,
                    title: "Duplication Failed",
                    message: "Failed to save meals for next week: \(error.localizedDescription)"
                )
            }
            
        } catch {
            print("❌ [BatchOperations] Error duplicating to next week: \(error)")
            return BatchOperationResult(
                isSuccess: false,
                title: "Duplication Failed",
                message: "Failed to duplicate week: \(error.localizedDescription)"
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadWeeklyGridFromCache(for weekStartDate: Date) async -> WeeklyMealGrid {
        // Try to load from local cache first
        if let cachedGrid = localStorageService.loadMealPlan(for: weekStartDate) {
            return cachedGrid
        }
        
        // Return empty grid if nothing found
        return WeeklyMealGrid()
    }
    
    private func countTotalMeals(in grid: WeeklyMealGrid) -> Int {
        var count = 0
        for dayMeals in grid.dailyMeals {
            count += dayMeals.breakfast.count
            count += dayMeals.lunch.count
            count += dayMeals.dinner.count
        }
        return count
    }
    
    private func convertMealPlanItemsToGrid(_ items: [MealPlanItem]) -> WeeklyMealGrid {
        var grid = WeeklyMealGrid()
        
        for item in items {
            guard let recipe = item.recipe else { continue }
            let dayIndex = item.dayOfWeek
            
            // Ensure we have enough days in the grid
            while grid.dailyMeals.count <= dayIndex {
                let calendar = Calendar.current
                let date = calendar.date(byAdding: .day, value: grid.dailyMeals.count, to: Date().startOfWeek()) ?? Date()
                let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
                let dayName = grid.dailyMeals.count < dayNames.count ? dayNames[grid.dailyMeals.count] : "Unknown"
                grid.dailyMeals.append(DailyMealSlots(day: dayName, date: date))
            }
            
            // Add recipe to appropriate meal type
            switch item.mealType {
            case "breakfast":
                grid.dailyMeals[dayIndex].breakfast.append(recipe)
            case "lunch":
                grid.dailyMeals[dayIndex].lunch.append(recipe)
            case "dinner":
                grid.dailyMeals[dayIndex].dinner.append(recipe)
            default:
                // Default to dinner if meal type is unrecognized
                grid.dailyMeals[dayIndex].dinner.append(recipe)
            }
        }
        
        return grid
    }
}

// Note: BatchOperationResult is defined in BatchOperationModels.swift