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
    
    /// Get Monday-based weekday (Monday = 0, Tuesday = 1, etc.)
    func mondayBasedWeekday() -> Int {
        return Calendar.mondayFirst.mondayBasedWeekday(for: self)
    }
}