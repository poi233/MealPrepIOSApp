import SwiftUI
import Foundation

// MARK: - Color Extensions
extension Color {
    static let primaryTeal = Color(red: 77/255, green: 182/255, blue: 172/255)
    static let accentMustard = Color(red: 255/255, green: 179/255, blue: 0/255)
}

// MARK: - String Extensions
extension String {
    var isValidEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: self)
    }
}

// MARK: - Calendar Extensions
extension Calendar {
    /// Calendar configured with Monday as the first day of the week
    /// This ensures consistent week calculations throughout the app
    static let mondayFirst: Calendar = {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday = 2 in Calendar.component(.weekday, ...)
        return calendar
    }()
    
    /// Get the start of the week (Monday) for a given date
    func startOfWeek(for date: Date) -> Date {
        let calendar = Calendar.mondayFirst
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
    
    /// Get the weekday index with Monday = 0, Tuesday = 1, etc.
    func mondayBasedWeekday(for date: Date) -> Int {
        let calendar = Calendar.mondayFirst
        let weekday = calendar.component(.weekday, from: date)
        // Convert from Sunday=1 to Monday=0 based indexing
        return weekday == 1 ? 6 : weekday - 2
    }
}

// MARK: - Date Extensions
extension Date {
    func formatted(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        return formatter.string(from: self)
    }
    
    /// Get the start of the week (Monday) for this date
    func startOfWeek() -> Date {
        return Calendar.mondayFirst.startOfWeek(for: self)
    }
    
    /// Returns the start of the week (Monday) for this date (with calendar parameter)
    func startOfWeek(using calendar: Calendar = Calendar.mondayFirst) -> Date {
        return calendar.startOfWeek(for: self)
    }
    
    /// Get Monday-based weekday (Monday = 0, Tuesday = 1, etc.)
    func mondayBasedWeekday() -> Int {
        return Calendar.mondayFirst.mondayBasedWeekday(for: self)
    }
    
    /// Returns the day of week index (0 = Monday, 1 = Tuesday, ..., 6 = Sunday)
    func dayOfWeekIndex(using calendar: Calendar = Calendar.mondayFirst) -> Int {
        return calendar.mondayBasedWeekday(for: self)
    }
    
    /// Returns the end of the week (Sunday) for this date
    func endOfWeek(using calendar: Calendar = Calendar.mondayFirst) -> Date {
        let startOfWeek = self.startOfWeek(using: calendar)
        return calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? self
    }
    
    /// Returns true if this date is in the same week as the other date
    func isSameWeek(as other: Date, using calendar: Calendar = Calendar.mondayFirst) -> Bool {
        let thisWeekStart = self.startOfWeek(using: calendar)
        let otherWeekStart = other.startOfWeek(using: calendar)
        return calendar.isDate(thisWeekStart, inSameDayAs: otherWeekStart)
    }
    
    /// Returns the name of the day of week
    func dayOfWeekName(using calendar: Calendar = Calendar.mondayFirst) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self)
    }
    
    /// Returns the short name of the day of week (Mon, Tue, etc.)
    func shortDayOfWeekName(using calendar: Calendar = Calendar.mondayFirst) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "EEE"
        return formatter.string(from: self)
    }
}

// MARK: - DateFormatter Extensions
extension DateFormatter {
    /// Formatter for week range display (MMM d - MMM d, yyyy)
    static let weekRange: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.mondayFirst
        return formatter
    }()
    
    /// Format a week range string (e.g., "Jan 15 - Jan 21, 2024")
    static func weekRangeString(from startDate: Date) -> String {
        let calendar = Calendar.mondayFirst
        let endDate = calendar.date(byAdding: .day, value: 6, to: startDate) ?? startDate
        
        let formatter = DateFormatter()
        formatter.calendar = calendar
        
        // Check if start and end are in the same month and year
        let startComponents = calendar.dateComponents([.year, .month], from: startDate)
        let endComponents = calendar.dateComponents([.year, .month], from: endDate)
        
        if startComponents.year == endComponents.year && startComponents.month == endComponents.month {
            // Same month: "Jan 15 - 21, 2024"
            formatter.dateFormat = "MMM d"
            let startString = formatter.string(from: startDate)
            formatter.dateFormat = "d, yyyy"
            let endString = formatter.string(from: endDate)
            return "\(startString) - \(endString)"
        } else if startComponents.year == endComponents.year {
            // Same year, different month: "Jan 30 - Feb 5, 2024"
            formatter.dateFormat = "MMM d"
            let startString = formatter.string(from: startDate)
            formatter.dateFormat = "MMM d, yyyy"
            let endString = formatter.string(from: endDate)
            return "\(startString) - \(endString)"
        } else {
            // Different year: "Dec 30, 2023 - Jan 5, 2024"
            formatter.dateFormat = "MMM d, yyyy"
            let startString = formatter.string(from: startDate)
            let endString = formatter.string(from: endDate)
            return "\(startString) - \(endString)"
        }
    }
}