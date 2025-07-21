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

// MARK: - Date Extensions
extension Date {
    func formatted(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        return formatter.string(from: self)
    }
}