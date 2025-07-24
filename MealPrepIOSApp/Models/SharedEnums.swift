//
//  SharedEnums.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/20/25.
//

import Foundation

// MARK: - Shared Enums

enum MealType: String, CaseIterable, Codable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    
    var displayName: String {
        return rawValue.capitalized
    }
}

enum Difficulty: String, CaseIterable, Codable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    
    var displayName: String {
        return rawValue.capitalized
    }
}

enum AnalysisType: String, CaseIterable, Codable {
    case nutrition = "nutrition"
    case variety = "variety"
    case balance = "balance"
    case full = "full"
    
    var displayName: String {
        return rawValue.capitalized
    }
}

enum BudgetLevel: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low:
            return "Budget-Friendly"
        case .medium:
            return "Moderate"
        case .high:
            return "Premium"
        }
    }
}