//
//  ShoppingListView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var showingCompletedItems = true
    @State private var sortOrder: ShoppingSortOrder = .category

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if mealPlanStore.shoppingList.isEmpty && !mealPlanStore.isLoadingShoppingList {
                    EmptyShoppingListView {
                        generateShoppingList()
                    }
                } else if mealPlanStore.isLoadingShoppingList {
                    LoadingShoppingListView()
                } else {
                    ShoppingListContentView(
                        searchText: $searchText,
                        showingCompletedItems: $showingCompletedItems,
                        sortOrder: $sortOrder
                    )
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Regenerate List") {
                            generateShoppingList()
                        }

                        Button("Share List") {
                            shareShoppingList()
                        }

                        Divider()

                        Button(showingCompletedItems ? "Hide Completed" : "Show Completed") {
                            showingCompletedItems.toggle()
                        }

                        Menu("Sort By") {
                            ForEach(ShoppingSortOrder.allCases, id: \.self) { order in
                                Button(order.displayName) {
                                    sortOrder = order
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search ingredients...")
        }
    }

    private func generateShoppingList() {
        Task {
            await mealPlanStore.generateShoppingList()
        }
    }

    private func shareShoppingList() {
        // TODO: Implement sharing functionality
    }
}

// MARK: - Empty Shopping List View

struct EmptyShoppingListView: View {
    let onGenerate: () -> Void
    @EnvironmentObject var mealPlanStore: MealPlanStore

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "cart.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text("No Shopping List Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                if mealPlanStore.weeklyGrid.hasAnyMeals {
                    Text("Generate a shopping list from your current meal plan to see all the ingredients you'll need.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
                        Text("Add some meals to your week first, then generate a shopping list to see all the ingredients you'll need.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("💡 Tip: Try using the 'Auto-fill with AI' feature in batch operations to get started quickly!")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }

            Button("Generate Shopping List") {
                onGenerate()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!mealPlanStore.weeklyGrid.hasAnyMeals)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Loading Shopping List View

struct LoadingShoppingListView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Generating Shopping List...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shopping List Content View

struct ShoppingListContentView: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @Binding var searchText: String
    @Binding var showingCompletedItems: Bool
    @Binding var sortOrder: ShoppingSortOrder

    var body: some View {
        VStack(spacing: 0) {
            // Progress Bar
            ShoppingProgressView()

            // Shopping List
            List {
                ForEach(filteredAndSortedItems, id: \.id) { item in
                    ShoppingListItemRow(item: item) {
                        mealPlanStore.toggleShoppingListItem(item)
                    }
                }
            }
            .listStyle(PlainListStyle())
        }
    }

    private var filteredAndSortedItems: [ShoppingListItem] {
        var items = mealPlanStore.shoppingList

        // Filter by search text
        if !searchText.isEmpty {
            items = items.filter { item in
                item.ingredient.localizedCaseInsensitiveContains(searchText) ||
                item.recipes.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        // Filter by completion status
        if !showingCompletedItems {
            items = items.filter { !$0.isCompleted }
        }

        // Sort items
        switch sortOrder {
        case .alphabetical:
            items.sort { $0.ingredient < $1.ingredient }
        case .category:
            items.sort { item1, item2 in
                let category1 = categorizeIngredient(item1.ingredient)
                let category2 = categorizeIngredient(item2.ingredient)
                if category1 == category2 {
                    return item1.ingredient < item2.ingredient
                }
                return category1 < category2
            }
        case .recipe:
            items.sort { $0.recipes.first ?? "" < $1.recipes.first ?? "" }
        case .completed:
            items.sort { !$0.isCompleted && $1.isCompleted }
        }

        return items
    }

    private func categorizeIngredient(_ ingredient: String) -> String {
        let lowercased = ingredient.lowercased()

        if lowercased.contains("meat") || lowercased.contains("chicken") || lowercased.contains("beef") || lowercased.contains("pork") {
            return "Meat & Poultry"
        } else if lowercased.contains("fish") || lowercased.contains("salmon") || lowercased.contains("tuna") {
            return "Seafood"
        } else if lowercased.contains("milk") || lowercased.contains("cheese") || lowercased.contains("yogurt") || lowercased.contains("butter") {
            return "Dairy"
        } else if lowercased.contains("bread") || lowercased.contains("pasta") || lowercased.contains("rice") || lowercased.contains("flour") {
            return "Grains & Bread"
        } else if lowercased.contains("apple") || lowercased.contains("banana") || lowercased.contains("orange") || lowercased.contains("berry") {
            return "Fruits"
        } else if lowercased.contains("lettuce") || lowercased.contains("tomato") || lowercased.contains("onion") || lowercased.contains("carrot") {
            return "Vegetables"
        } else {
            return "Other"
        }
    }
}

// MARK: - Shopping Progress View

struct ShoppingProgressView: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore

    var body: some View {
        let completedCount = mealPlanStore.shoppingList.filter { $0.isCompleted }.count
        let totalCount = mealPlanStore.shoppingList.count
        let progress = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0

        VStack(spacing: 8) {
            HStack {
                Text("Shopping Progress")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(completedCount) of \(totalCount) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .primaryGreen))
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - Shopping List Item Row

struct ShoppingListItemRow: View {
    let item: ShoppingListItem
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? .primaryGreen : .secondary)
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())

            // Item Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.ingredient)
                        .font(.body)
                        .fontWeight(.medium)
                        .strikethrough(item.isCompleted)
                        .foregroundColor(item.isCompleted ? .secondary : .primary)

                    Spacer()

                    if !item.amount.isEmpty {
                        Text("\(item.amount) \(item.unit)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Recipes using this ingredient
                if !item.recipes.isEmpty {
                    Text("Used in: \(item.recipes.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

// MARK: - Shopping List Sheet

struct MealPlanListSheet: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            MealPlanView()
                .navigationTitle("Meal Plans")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Supporting Enums

enum ShoppingSortOrder: CaseIterable {
    case alphabetical, category, recipe, completed

    var displayName: String {
        switch self {
        case .alphabetical:
            return "Alphabetical"
        case .category:
            return "Category"
        case .recipe:
            return "Recipe"
        case .completed:
            return "Completed First"
        }
    }
}

#Preview {
    ShoppingListView()
        .environmentObject(MealPlanStore())
}