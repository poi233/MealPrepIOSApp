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

    // 支持中英文多种表示方式的初始化器
    init?(from value: String) {
        let lowercased = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        switch lowercased {
        case "easy", "简单", "容易", "初级":
            self = .easy
        case "medium", "中等", "中级", "普通", "moderate":
            self = .medium
        case "hard", "困难", "难", "高级", "difficult", "challenging":
            self = .hard
        default:
            return nil
        }
    }

    // 自定义解码器支持中英文
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)

        if let difficulty = Difficulty(from: stringValue) {
            self = difficulty
        } else {
            // 如果无法识别，默认为medium
            print("⚠️ [Difficulty] Unknown difficulty value: '\(stringValue)', defaulting to medium")
            self = .medium
        }
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

enum WeekDirection: String, CaseIterable {
    case previous = "previous"
    case current = "current"
    case next = "next"

    var displayName: String {
        switch self {
        case .previous:
            return "Previous Week"
        case .current:
            return "Current Week"
        case .next:
            return "Next Week"
        }
    }
}