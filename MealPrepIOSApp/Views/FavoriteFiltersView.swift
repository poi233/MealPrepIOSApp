//
//  FavoriteFiltersView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import SwiftUI

struct FavoriteFiltersView: View {
    @EnvironmentObject var favoritesStore: FavoritesStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRating: Int?
    @State private var minRating: Double = 0
    @State private var maxRating: Double = 5
    @State private var selectedCuisine: String?
    @State private var selectedDifficulty: Difficulty?
    @State private var dateRange: DateRange = .anytime
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var sortOrder: FavoriteOrdering = .addedAtDesc
    
    private let cuisines = ["Italian", "Asian", "Mexican", "American", "French", "Indian", "Mediterranean", "Thai", "Japanese", "Chinese"]
    private let difficulties = Difficulty.allCases
    
    var body: some View {
        NavigationView {
            Form {
                Section("Rating") {
                    VStack(alignment: .leading, spacing: 16) {
                        // Specific Rating
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Exact Rating")
                                .font(.subheadline)
                            
                            HStack(spacing: 12) {
                                Button("Any") {
                                    selectedRating = nil
                                }
                                .buttonStyle(FilterButtonStyle(isSelected: selectedRating == nil))
                                
                                ForEach(1...5, id: \.self) { rating in
                                    Button("\(rating)★") {
                                        selectedRating = rating
                                    }
                                    .buttonStyle(FilterButtonStyle(isSelected: selectedRating == rating))
                                }
                            }
                        }
                        
                        // Rating Range
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rating Range: \(Int(minRating))★ - \(Int(maxRating))★")
                                .font(.subheadline)
                            
                            HStack {
                                Text("Min")
                                Slider(value: $minRating, in: 0...5, step: 1)
                                Text("Max")
                                Slider(value: $maxRating, in: 0...5, step: 1)
                            }
                        }
                    }
                }
                
                Section("Cuisine") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button("Any") {
                                selectedCuisine = nil
                            }
                            .buttonStyle(FilterButtonStyle(isSelected: selectedCuisine == nil))
                            
                            ForEach(cuisines, id: \.self) { cuisine in
                                Button(cuisine) {
                                    selectedCuisine = selectedCuisine == cuisine ? nil : cuisine
                                }
                                .buttonStyle(FilterButtonStyle(isSelected: selectedCuisine == cuisine))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Section("Difficulty") {
                    HStack(spacing: 12) {
                        Button("Any") {
                            selectedDifficulty = nil
                        }
                        .buttonStyle(FilterButtonStyle(isSelected: selectedDifficulty == nil))
                        
                        ForEach(difficulties, id: \.self) { difficulty in
                            Button(difficulty.displayName) {
                                selectedDifficulty = selectedDifficulty == difficulty ? nil : difficulty
                            }
                            .buttonStyle(FilterButtonStyle(isSelected: selectedDifficulty == difficulty))
                        }
                        Spacer()
                    }
                }
                
                Section("Date Added") {
                    Picker("Date Range", selection: $dateRange) {
                        ForEach(DateRange.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    if dateRange == .custom {
                        DatePicker("From", selection: $customStartDate, displayedComponents: .date)
                        DatePicker("To", selection: $customEndDate, displayedComponents: .date)
                    }
                }
                
                Section("Sort Order") {
                    Picker("Sort By", selection: $sortOrder) {
                        ForEach(FavoriteOrdering.allCases, id: \.self) { order in
                            Text(order.displayName).tag(order)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            .navigationTitle("Filter Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        clearAllFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyFilters()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadCurrentFilters()
            }
        }
    }
    
    private func loadCurrentFilters() {
        selectedRating = favoritesStore.selectedRating
        selectedCuisine = favoritesStore.selectedCuisine
        selectedDifficulty = favoritesStore.selectedDifficulty
        sortOrder = favoritesStore.sortOrder
        
        minRating = Double(favoritesStore.filters.personalRatingMin ?? 0)
        maxRating = Double(favoritesStore.filters.personalRatingMax ?? 5)
        
        // Set date range based on current filters
        if let startDate = favoritesStore.filters.addedAtMin,
           let endDate = favoritesStore.filters.addedAtMax {
            dateRange = .custom
            customStartDate = startDate
            customEndDate = endDate
        } else {
            dateRange = .anytime
        }
    }
    
    private func applyFilters() {
        favoritesStore.selectedRating = selectedRating
        favoritesStore.selectedCuisine = selectedCuisine
        favoritesStore.selectedDifficulty = selectedDifficulty
        favoritesStore.sortOrder = sortOrder
        
        let startDate: Date?
        let endDate: Date?
        
        switch dateRange {
        case .anytime:
            startDate = nil
            endDate = nil
        case .lastWeek:
            endDate = Date()
            startDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: endDate!)
        case .lastMonth:
            endDate = Date()
            startDate = Calendar.current.date(byAdding: .month, value: -1, to: endDate!)
        case .lastYear:
            endDate = Date()
            startDate = Calendar.current.date(byAdding: .year, value: -1, to: endDate!)
        case .custom:
            startDate = customStartDate
            endDate = customEndDate
        }
        
        favoritesStore.filters = FavoriteFilters(
            search: favoritesStore.searchQuery.isEmpty ? nil : favoritesStore.searchQuery,
            personalRating: selectedRating,
            personalRatingMin: minRating > 0 ? Int(minRating) : nil,
            personalRatingMax: maxRating < 5 ? Int(maxRating) : nil,
            recipeCuisine: selectedCuisine,
            recipeDifficulty: selectedDifficulty,
            addedAtMin: startDate,
            addedAtMax: endDate,
            ordering: sortOrder
        )
        
        Task {
            await favoritesStore.applyFilters()
        }
    }
    
    private func clearAllFilters() {
        selectedRating = nil
        minRating = 0
        maxRating = 5
        selectedCuisine = nil
        selectedDifficulty = nil
        dateRange = .anytime
        sortOrder = .addedAtDesc
    }
}

// MARK: - Supporting Types

enum DateRange: CaseIterable {
    case anytime, lastWeek, lastMonth, lastYear, custom
    
    var displayName: String {
        switch self {
        case .anytime:
            return "Anytime"
        case .lastWeek:
            return "Last Week"
        case .lastMonth:
            return "Last Month"
        case .lastYear:
            return "Last Year"
        case .custom:
            return "Custom Range"
        }
    }
}

struct FilterButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.primaryGreen : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

#Preview {
    FavoriteFiltersView()
        .environmentObject(FavoritesStore())
}