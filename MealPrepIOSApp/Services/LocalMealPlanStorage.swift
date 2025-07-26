//
//  LocalMealPlanStorage.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/22/25.
//

import Foundation

// MARK: - Local Storage Errors
enum LocalStorageError: LocalizedError {
    case encodingFailed(Error)
    case decodingFailed(Error)
    case saveVerificationFailed
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed(let error):
            return "Failed to encode meal plan data: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode meal plan data: \(error.localizedDescription)"
        case .saveVerificationFailed:
            return "Data was not saved properly - verification failed"
        }
    }
}

class LocalMealPlanStorage {
    static let shared = LocalMealPlanStorage()
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    
    private init() {
        createStorageDirectoryIfNeeded()
        migrateLegacyDataIfNeeded()
    }
    
    // MARK: - Constants
    private let weeklyMealPlanKey = "weeklyMealPlan" // Legacy key
    private let multiWeekKeyPrefix = "weeklyMealPlan_"
    private let maxStoredWeeks = 6
    private let storageDirectoryName = "MealPlans"
    
    // MARK: - Storage Directory Management
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var storageDirectory: URL {
        documentsDirectory.appendingPathComponent(storageDirectoryName)
    }
    
    private func createStorageDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    private func fileURL(for weekStartDate: Date) -> URL {
        let fileName = "\(formatWeekDate(weekStartDate)).json"
        return storageDirectory.appendingPathComponent(fileName)
    }
    
    // MARK: - Storage Methods
    
    /// Save weekly meal plan for a specific week
    func saveWeeklyMealPlan(for weekStartDate: Date, _ weeklyGrid: WeeklyMealGrid) -> Result<Void, LocalStorageError> {
        let normalizedDate = normalizeWeekStartDate(weekStartDate)
        let fileURL = fileURL(for: normalizedDate)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(weeklyGrid)
            
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            
            // Verify save
            guard let savedData = try? Data(contentsOf: fileURL) else {
                return .failure(.saveVerificationFailed)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let _ = try? decoder.decode(WeeklyMealGrid.self, from: savedData) else {
                return .failure(.saveVerificationFailed)
            }
            
            // Backup to UserDefaults
            saveToUserDefaultsBackup(for: normalizedDate, weeklyGrid)
            cleanupOldWeeks()
            
            return .success(())
        } catch {
            return .failure(.encodingFailed(error))
        }
    }
    
    /// Save to UserDefaults as backup
    private func saveToUserDefaultsBackup(for weekStartDate: Date, _ weeklyGrid: WeeklyMealGrid) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(weeklyGrid) else { return }
        let key = generateWeekKey(for: weekStartDate)
        userDefaults.set(data, forKey: key)
    }
    
    /// Load weekly meal plan for a specific week
    func loadWeeklyMealPlan(for weekStartDate: Date) -> WeeklyMealGrid? {
        let normalizedDate = normalizeWeekStartDate(weekStartDate)
        let fileURL = fileURL(for: normalizedDate)
        
        // Try to load from file first
        if let data = try? Data(contentsOf: fileURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let weeklyGrid = try? decoder.decode(WeeklyMealGrid.self, from: data) {
                return weeklyGrid
            }
        }
        
        // Fallback to UserDefaults backup
        let key = generateWeekKey(for: normalizedDate)
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let weeklyGrid = try? decoder.decode(WeeklyMealGrid.self, from: data) else {
            return nil
        }
        
        // Save to file for future use
        _ = saveWeeklyMealPlan(for: normalizedDate, weeklyGrid)
        return weeklyGrid
    }
    
    /// Clear meal plan for a specific week
    func clearMealPlan(for weekStartDate: Date) {
        let normalizedDate = normalizeWeekStartDate(weekStartDate)
        let fileURL = fileURL(for: normalizedDate)
        let key = generateWeekKey(for: normalizedDate)
        
        try? fileManager.removeItem(at: fileURL)
        userDefaults.removeObject(forKey: key)
    }
    
    /// Get all stored week start dates
    func getAllStoredWeeks() -> [Date] {
        var dates: [Date] = []
        
        // Get dates from files
        if let fileURLs = try? fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil) {
            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }
            dates.append(contentsOf: jsonFiles.compactMap { fileURL in
                let fileName = fileURL.deletingPathExtension().lastPathComponent
                return weekDateFormatter.date(from: fileName)
            })
        }
        
        // Check UserDefaults for backup data
        let allKeys = Array(userDefaults.dictionaryRepresentation().keys)
        let weekKeys = allKeys.filter { $0.hasPrefix(multiWeekKeyPrefix) }
        let userDefaultsDates = weekKeys.compactMap { key -> Date? in
            let dateString = String(key.dropFirst(multiWeekKeyPrefix.count))
            return weekDateFormatter.date(from: dateString)
        }
        
        dates.append(contentsOf: userDefaultsDates)
        return Array(Set(dates)).sorted()
    }
    
    // MARK: - Cleanup Methods
    
    /// Force cleanup of invalid weeks (outside ±4 weeks from current)
    func forceCleanupInvalidWeeks() {
        let calendar = Calendar.current
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        
        let storedWeeks = getAllStoredWeeks()
        for week in storedWeeks {
            let weekDifference = calendar.dateComponents([.weekOfYear], from: currentWeekStart, to: week).weekOfYear ?? 0
            if abs(weekDifference) > 4 {
                clearMealPlan(for: week)
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func generateWeekKey(for weekStartDate: Date) -> String {
        "\(multiWeekKeyPrefix)\(formatWeekDate(weekStartDate))"
    }
    
    private func formatWeekDate(_ date: Date) -> String {
        weekDateFormatter.string(from: date)
    }
    
    /// Normalize week start date to remove time components and ensure consistency
    private func normalizeWeekStartDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: components) ?? date
    }
    
    private func cleanupOldWeeks() {
        let storedWeeks = getAllStoredWeeks()
        if storedWeeks.count > maxStoredWeeks {
            let weeksToRemove = storedWeeks.dropLast(maxStoredWeeks)
            weeksToRemove.forEach { clearMealPlan(for: $0) }
        }
    }
    
    private func migrateLegacyDataIfNeeded() {
        guard let legacyData = userDefaults.data(forKey: weeklyMealPlanKey) else {
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let legacyGrid = try? decoder.decode(WeeklyMealGrid.self, from: legacyData) else {
            return
        }
        
        _ = saveWeeklyMealPlan(for: legacyGrid.weekStartDate, legacyGrid)
        userDefaults.removeObject(forKey: weeklyMealPlanKey)
    }
    
    // MARK: - Date Formatter
    
    private lazy var weekDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}