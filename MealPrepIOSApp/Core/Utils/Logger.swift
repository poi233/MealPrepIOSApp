import Foundation
import os.log
import OSLog

// MARK: - Structured Logging System

/// Centralized logging system for the MealPrep iOS app
/// Replaces scattered print statements with structured, categorized logging
struct AppLogger {
    
    // MARK: - Log Categories
    enum Category: String, CaseIterable {
        case authentication = "🔐 Auth"
        case networking = "🌐 Network"
        case coreData = "💾 CoreData"
        case userInterface = "📱 UI"
        case mealPlanning = "🍽️ MealPlanning"
        case aiGeneration = "🤖 AI"
        case caching = "💿 Cache"
        case storage = "📦 Storage"
        case performance = "⚡ Performance"
        case dateCalculation = "📅 DateCalc"
        case error = "❌ Error"
        case general = "ℹ️ General"
        
        var subsystem: String {
            return "com.mealprep.app"
        }
        
        var osLog: OSLog {
            return OSLog(subsystem: subsystem, category: self.rawValue)
        }
    }
    
    // MARK: - Log Levels
    enum Level: String, CaseIterable {
        case debug = "🔍 DEBUG"
        case info = "ℹ️ INFO"
        case warning = "⚠️ WARNING"
        case error = "❌ ERROR"
        case critical = "🚨 CRITICAL"
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }
    
    // MARK: - Logging Methods
    
    /// Log a debug message (only in DEBUG builds)
    static func debug(_ message: @autoclosure () -> String, category: Category = .general, file: String = #fileID, function: String = #function, line: Int = #line) {
        #if DEBUG
        log(level: .debug, message: message(), category: category, file: file, function: function, line: line)
        #endif
    }
    
    /// Log an informational message
    static func info(_ message: @autoclosure () -> String, category: Category = .general, file: String = #fileID, function: String = #function, line: Int = #line) {
        log(level: .info, message: message(), category: category, file: file, function: function, line: line)
    }
    
    /// Log a warning message
    static func warning(_ message: @autoclosure () -> String, category: Category = .general, file: String = #fileID, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message(), category: category, file: file, function: function, line: line)
    }
    
    /// Log an error message
    static func error(_ message: @autoclosure () -> String, category: Category = .error, file: String = #fileID, function: String = #function, line: Int = #line) {
        log(level: .error, message: message(), category: category, file: file, function: function, line: line)
    }
    
    /// Log a critical error message
    static func critical(_ message: @autoclosure () -> String, category: Category = .error, file: String = #fileID, function: String = #function, line: Int = #line) {
        log(level: .critical, message: message(), category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Specialized Logging Methods
    
    /// Log network operations with request/response details
    static func network(_ message: @autoclosure () -> String, url: String? = nil, statusCode: Int? = nil, duration: TimeInterval? = nil, file: String = #fileID, function: String = #function, line: Int = #line) {
        var logMessage = message()
        if let url = url { logMessage += " | URL: \(url)" }
        if let statusCode = statusCode { logMessage += " | Status: \(statusCode)" }
        if let duration = duration { logMessage += " | Duration: \(String(format: "%.2f", duration))s" }
        
        info(logMessage, category: .networking, file: file, function: function, line: line)
    }
    
    /// Log performance metrics
    static func performance(_ message: @autoclosure () -> String, duration: TimeInterval, threshold: TimeInterval = 1.0, file: String = #fileID, function: String = #function, line: Int = #line) {
        let level: Level = duration > threshold ? .warning : .info
        let logMessage = "\(message()) | Duration: \(String(format: "%.3f", duration))s"
        log(level: level, message: logMessage, category: .performance, file: file, function: function, line: line)
    }
    
    /// Log user actions for analytics
    static func userAction(_ action: String, details: [String: Any] = [:], category: Category = .userInterface, file: String = #fileID, function: String = #function, line: Int = #line) {
        var message = "User Action: \(action)"
        if !details.isEmpty {
            let detailsString = details.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            message += " | Details: [\(detailsString)]"
        }
        info(message, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Core Logging Implementation
    
    private static func log(level: Level, message: String, category: Category, file: String, function: String, line: Int) {
        let timestamp = DateFormatter.logTimestamp.string(from: Date())
        let fileName = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        
        let logMessage = "[\(timestamp)] \(level.rawValue) \(category.rawValue) [\(fileName):\(line)] \(function) - \(message)"
        
        // Console output for development
        #if DEBUG
        print(logMessage)
        #endif
        
        // Structured logging for production (OSLog)
        if #available(iOS 14.0, *) {
            let osLogger = os.Logger(subsystem: category.subsystem, category: category.rawValue)
            switch level {
            case .debug:
                osLogger.debug("\(message)")
            case .info:
                osLogger.info("\(message)")
            case .warning:
                osLogger.notice("\(message)")
            case .error:
                osLogger.error("\(message)")
            case .critical:
                osLogger.critical("\(message)")
            }
        } else {
            // Fallback to OSLog for iOS 13
            os_log("%@", log: category.osLog, type: level.osLogType, message)
        }
    }
}

// MARK: - Extensions

private extension DateFormatter {
    static let logTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Legacy Support

/// Note: Use AppLogger directly instead of the old Logger alias to avoid conflicts with OSLog.Logger

