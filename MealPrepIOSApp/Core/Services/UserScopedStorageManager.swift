//
//  UserScopedStorageManager.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/27/25.
//

import Foundation

// MARK: - User Scoped Storage Errors
enum UserScopedStorageError: LocalizedError {
    case noCurrentUser
    case invalidUserID
    case storageError(Error)
    case migrationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noCurrentUser:
            return "No current user available for scoped storage"
        case .invalidUserID:
            return "Invalid user ID provided"
        case .storageError(let error):
            return "Storage operation failed: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "Data migration failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Storage Backend Protocol
protocol StorageBackend {
    func getValue(forKey key: String) -> Any?
    func setValue(_ value: Any?, forKey key: String)
    func removeValue(forKey key: String)
    func getAllKeys() -> [String]
}

// MARK: - UserDefaults Storage Backend
class UserDefaultsStorageBackend: StorageBackend {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func getValue(forKey key: String) -> Any? {
        return userDefaults.object(forKey: key)
    }

    func setValue(_ value: Any?, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }

    func removeValue(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }

    func getAllKeys() -> [String] {
        return Array(userDefaults.dictionaryRepresentation().keys)
    }
}

// MARK: - File System Storage Backend
class FileSystemStorageBackend: StorageBackend {
    private let baseDirectory: URL
    private let fileManager: FileManager

    init(baseDirectory: URL? = nil) {
        self.fileManager = FileManager.default
        
        // Use provided directory or fallback to default documents directory
        if let providedDirectory = baseDirectory {
            self.baseDirectory = providedDirectory
        } else {
            if let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                self.baseDirectory = documentsDir
            } else {
                AppLogger.error("Failed to get documents directory, using temporary directory", category: .storage)
                self.baseDirectory = fileManager.temporaryDirectory.appendingPathComponent("UserScopedStorage")
            }
        }
        
        createBaseDirectoryIfNeeded()
    }

    private func createBaseDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }

    private func fileURL(forKey key: String) -> URL {
        return baseDirectory.appendingPathComponent("\(key).json")
    }

    func getValue(forKey key: String) -> Any? {
        let url = fileURL(forKey: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    func setValue(_ value: Any?, forKey key: String) {
        let url = fileURL(forKey: key)

        guard let value = value else {
            try? fileManager.removeItem(at: url)
            return
        }

        guard let data = try? JSONSerialization.data(withJSONObject: value) else {
            return
        }

        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    func removeValue(forKey key: String) {
        let url = fileURL(forKey: key)
        try? fileManager.removeItem(at: url)
    }

    func getAllKeys() -> [String] {
        guard let files = try? fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil) else {
            return []
        }

        return files.compactMap { url in
            guard url.pathExtension == "json" else { return nil }
            return url.deletingPathExtension().lastPathComponent
        }
    }
}

// MARK: - User Scoped Storage Manager
class UserScopedStorageManager {
    static let shared = UserScopedStorageManager()

    private let userDefaultsBackend: UserDefaultsStorageBackend
    private let fileSystemBackend: FileSystemStorageBackend
    private let migrationManager: StorageMigrationManager

    // User ID provider - this will be set by AuthStore when user logs in/out
    private var currentUserID: String?
    private let anonymousUserID = "anonymous"
    private let lastUserIDKey = "last_logged_in_user_id"

    private init() {
        self.userDefaultsBackend = UserDefaultsStorageBackend()

        // Create user-scoped file system backend with safe directory access
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let userScopedDirectory = documentsDirectory.appendingPathComponent("UserScopedStorage")
            self.fileSystemBackend = FileSystemStorageBackend(baseDirectory: userScopedDirectory)
        } else {
            AppLogger.error("Failed to get documents directory in UserScopedStorageManager init", category: .storage)
            // Use temporary directory as fallback
            let userScopedDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("UserScopedStorage")
            self.fileSystemBackend = FileSystemStorageBackend(baseDirectory: userScopedDirectory)
        }

        self.migrationManager = StorageMigrationManager(
            userDefaultsBackend: userDefaultsBackend,
            fileSystemBackend: fileSystemBackend
        )
    }

    // MARK: - User Management

    /// Set the current user ID for scoped storage operations
    func setCurrentUser(userID: String?) {
        print("🔑 [UserScopedStorage] Setting current user ID: \(userID ?? "nil")")
        self.currentUserID = userID

        // Persist the user ID for app restart recovery (only if not nil)
        if let userID = userID {
            userDefaultsBackend.setValue(userID, forKey: lastUserIDKey)
            migrationManager.migrateExistingDataIfNeeded(for: userID)
        }
    }

    /// Set the current user ID only for this session (doesn't persist for restart)
    func setCurrentUserTemporary(userID: String?) {
        print("🔑 [UserScopedStorage] Setting temporary user ID: \(userID ?? "nil")")
        self.currentUserID = userID

        // Trigger migration for new user if needed
        if let userID = userID {
            migrationManager.migrateExistingDataIfNeeded(for: userID)
        }
    }

    /// Restore user scope from persistent storage (for app startup)
    func restoreUserScopeOnStartup() -> String? {
        if let persistedUserID = userDefaultsBackend.getValue(forKey: lastUserIDKey) as? String {
            print("🔄 [UserScopedStorage] Restoring user scope on startup: \(persistedUserID)")
            self.currentUserID = persistedUserID
            return persistedUserID
        } else {
            print("🔄 [UserScopedStorage] No persisted user ID found on startup")
            return nil
        }
    }

    /// Clear the persisted user ID (only called on explicit logout)
    func clearPersistedUserID() {
        print("🗑️ [UserScopedStorage] Clearing persisted user ID")
        userDefaultsBackend.removeValue(forKey: lastUserIDKey)
        self.currentUserID = nil
    }

    /// Get the current effective user ID (falls back to anonymous if no user)
    private func effectiveUserID() -> String {
        return currentUserID ?? anonymousUserID
    }

    /// Create a scoped key with user prefix
    private func scopedKey(for key: String) -> String {
        return "\(effectiveUserID())_\(key)"
    }

    // MARK: - UserDefaults Storage Methods

    /// Store data in UserDefaults with user scoping (only for property list compatible types)
    func setUserDefaultsValue<T: Codable>(_ value: T?, forKey key: String) {
        let scopedKey = scopedKey(for: key)

        guard let value = value else {
            userDefaultsBackend.removeValue(forKey: scopedKey)
            print("🗑️ [UserScopedStorage] Removed from UserDefaults: \(scopedKey)")
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(value)
            userDefaultsBackend.setValue(data, forKey: scopedKey)
            print("💾 [UserScopedStorage] Saved to UserDefaults: \(scopedKey)")
        } catch {
            print("❌ [UserScopedStorage] Failed to encode value for UserDefaults: \(scopedKey) - \(error)")
        }
    }

    /// Retrieve data from UserDefaults with user scoping
    func getUserDefaultsValue<T: Codable>(forKey key: String, type: T.Type) -> T? {
        let scopedKey = scopedKey(for: key)

        guard let data = userDefaultsBackend.getValue(forKey: scopedKey) as? Data else {
            print("📖 [UserScopedStorage] Read from UserDefaults: \(scopedKey) -> nil")
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let value = try decoder.decode(T.self, from: data)
            print("📖 [UserScopedStorage] Read from UserDefaults: \(scopedKey) -> found")
            return value
        } catch {
            print("❌ [UserScopedStorage] Failed to decode value from UserDefaults: \(scopedKey) - \(error)")
            return nil
        }
    }

    /// Remove data from UserDefaults with user scoping
    func removeUserDefaultsValue(forKey key: String) {
        let scopedKey = scopedKey(for: key)
        userDefaultsBackend.removeValue(forKey: scopedKey)
        print("🗑️ [UserScopedStorage] Removed from UserDefaults: \(scopedKey)")
    }

    // MARK: - File System Storage Methods

    /// Store data in file system with user scoping
    func setFileSystemValue<T: Codable>(_ value: T?, forKey key: String) throws {
        let scopedKey = scopedKey(for: key)

        guard let value = value else {
            fileSystemBackend.removeValue(forKey: scopedKey)
            print("🗑️ [UserScopedStorage] Removed from file system: \(scopedKey)")
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(value)
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            fileSystemBackend.setValue(jsonObject, forKey: scopedKey)
            print("💾 [UserScopedStorage] Saved to file system: \(scopedKey)")
        } catch {
            print("❌ [UserScopedStorage] Failed to save to file system: \(scopedKey) - \(error)")
            throw UserScopedStorageError.storageError(error)
        }
    }

    /// Retrieve data from file system with user scoping
    func getFileSystemValue<T: Codable>(forKey key: String, type: T.Type) -> T? {
        let scopedKey = scopedKey(for: key)

        guard let jsonObject = fileSystemBackend.getValue(forKey: scopedKey) else {
            print("📖 [UserScopedStorage] Read from file system: \(scopedKey) -> nil")
            return nil
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: jsonObject)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let value = try decoder.decode(T.self, from: data)
            print("📖 [UserScopedStorage] Read from file system: \(scopedKey) -> found")
            return value
        } catch {
            print("❌ [UserScopedStorage] Failed to decode from file system: \(scopedKey) - \(error)")
            return nil
        }
    }

    /// Remove data from file system with user scoping
    func removeFileSystemValue(forKey key: String) {
        let scopedKey = scopedKey(for: key)
        fileSystemBackend.removeValue(forKey: scopedKey)
        print("🗑️ [UserScopedStorage] Removed from file system: \(scopedKey)")
    }

    // MARK: - Data Management

    /// Clear all data for the current user
    func clearCurrentUserData() {
        let userID = effectiveUserID()
        print("🧹 [UserScopedStorage] Clearing all data for user: \(userID)")

        // Clear UserDefaults
        let userDefaultsKeys = userDefaultsBackend.getAllKeys()
        let userScopedDefaultsKeys = userDefaultsKeys.filter { $0.hasPrefix("\(userID)_") }
        for key in userScopedDefaultsKeys {
            userDefaultsBackend.removeValue(forKey: key)
        }

        // Clear File System
        let fileSystemKeys = fileSystemBackend.getAllKeys()
        let userScopedFileKeys = fileSystemKeys.filter { $0.hasPrefix("\(userID)_") }
        for key in userScopedFileKeys {
            fileSystemBackend.removeValue(forKey: key)
        }

        // Clear persisted user ID (for explicit logout)
        clearPersistedUserID()

        print("✅ [UserScopedStorage] Cleared \(userScopedDefaultsKeys.count) UserDefaults keys and \(userScopedFileKeys.count) file system keys")
    }

    /// Clear all data for a specific user
    func clearDataForUser(_ userID: String) {
        print("🧹 [UserScopedStorage] Clearing all data for specific user: \(userID)")

        // Clear UserDefaults
        let userDefaultsKeys = userDefaultsBackend.getAllKeys()
        let userScopedDefaultsKeys = userDefaultsKeys.filter { $0.hasPrefix("\(userID)_") }
        for key in userScopedDefaultsKeys {
            userDefaultsBackend.removeValue(forKey: key)
        }

        // Clear File System
        let fileSystemKeys = fileSystemBackend.getAllKeys()
        let userScopedFileKeys = fileSystemKeys.filter { $0.hasPrefix("\(userID)_") }
        for key in userScopedFileKeys {
            fileSystemBackend.removeValue(forKey: key)
        }

        print("✅ [UserScopedStorage] Cleared \(userScopedDefaultsKeys.count) UserDefaults keys and \(userScopedFileKeys.count) file system keys for user \(userID)")
    }

    /// Get all stored user IDs
    func getAllStoredUserIDs() -> [String] {
        var userIDs = Set<String>()

        // Check UserDefaults
        let userDefaultsKeys = userDefaultsBackend.getAllKeys()
        for key in userDefaultsKeys {
            if let underscoreIndex = key.firstIndex(of: "_") {
                let userID = String(key[..<underscoreIndex])
                userIDs.insert(userID)
            }
        }

        // Check File System
        let fileSystemKeys = fileSystemBackend.getAllKeys()
        for key in fileSystemKeys {
            if let underscoreIndex = key.firstIndex(of: "_") {
                let userID = String(key[..<underscoreIndex])
                userIDs.insert(userID)
            }
        }

        return Array(userIDs).sorted()
    }

    /// Check if user has any stored data
    func hasDataForUser(_ userID: String) -> Bool {
        let userDefaultsKeys = userDefaultsBackend.getAllKeys()
        let fileSystemKeys = fileSystemBackend.getAllKeys()

        let hasUserDefaultsData = userDefaultsKeys.contains { $0.hasPrefix("\(userID)_") }
        let hasFileSystemData = fileSystemKeys.contains { $0.hasPrefix("\(userID)_") }

        return hasUserDefaultsData || hasFileSystemData
    }

    /// Get all scoped keys for the current user (without user prefix)
    func getCurrentUserKeys() -> (userDefaultsKeys: [String], fileSystemKeys: [String]) {
        let currentUserID = effectiveUserID()
        let prefix = "\(currentUserID)_"

        let userDefaultsKeys = userDefaultsBackend.getAllKeys()
            .filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }

        let fileSystemKeys = fileSystemBackend.getAllKeys()
            .filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }

        return (userDefaultsKeys, fileSystemKeys)
    }
}

// MARK: - Storage Migration Manager
class StorageMigrationManager {
    private let userDefaultsBackend: UserDefaultsStorageBackend
    private let fileSystemBackend: FileSystemStorageBackend
    private let migrationStatusKey = "storage_migration_completed_users"

    init(userDefaultsBackend: UserDefaultsStorageBackend, fileSystemBackend: FileSystemStorageBackend) {
        self.userDefaultsBackend = userDefaultsBackend
        self.fileSystemBackend = fileSystemBackend
    }

    /// Migrate existing non-scoped data to user-scoped format
    func migrateExistingDataIfNeeded(for userID: String) {
        // Check if migration has already been completed for this user
        let migratedUsers = getMigratedUsers()
        if migratedUsers.contains(userID) {
            print("✅ [Migration] Migration already completed for user: \(userID)")
            return
        }

        print("🔄 [Migration] Starting migration for user: \(userID)")

        // Migrate known legacy keys
        migrateLegacyMealPlanData(for: userID)

        // Mark migration as completed
        markMigrationCompleted(for: userID)

        print("✅ [Migration] Migration completed for user: \(userID)")
    }

    private func migrateLegacyMealPlanData(for userID: String) {
        // Legacy keys that need migration (documented for reference)
        // - "weeklyMealPlan": Legacy single week key
        // - "weeklyMealPlan_*": Multi-week keys with prefix pattern

        // Migrate UserDefaults data
        let allUserDefaultsKeys = userDefaultsBackend.getAllKeys()

        // Handle legacy weekly meal plan key
        if let legacyData = userDefaultsBackend.getValue(forKey: "weeklyMealPlan") {
            let newKey = "\(userID)_weeklyMealPlan_legacy"
            userDefaultsBackend.setValue(legacyData, forKey: newKey)
            userDefaultsBackend.removeValue(forKey: "weeklyMealPlan")
            print("📦 [Migration] Migrated legacy weekly meal plan to: \(newKey)")
        }

        // Handle multi-week keys (those starting with "weeklyMealPlan_")
        let multiWeekKeys = allUserDefaultsKeys.filter { $0.hasPrefix("weeklyMealPlan_") }
        for legacyKey in multiWeekKeys {
            if let legacyData = userDefaultsBackend.getValue(forKey: legacyKey) {
                let newKey = "\(userID)_\(legacyKey)"
                userDefaultsBackend.setValue(legacyData, forKey: newKey)
                userDefaultsBackend.removeValue(forKey: legacyKey)
                print("📦 [Migration] Migrated meal plan key: \(legacyKey) -> \(newKey)")
            }
        }

        // Migrate file system data (from legacy LocalMealPlanStorage directory structure)
        migrateLegacyFileSystemData(for: userID)
    }

    private func migrateLegacyFileSystemData(for userID: String) {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            AppLogger.error("Failed to get documents directory for legacy data migration", category: .storage)
            return
        }
        let legacyMealPlansDirectory = documentsDirectory.appendingPathComponent("MealPlans")

        guard fileManager.fileExists(atPath: legacyMealPlansDirectory.path) else {
            print("📁 [Migration] No legacy MealPlans directory found")
            return
        }

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: legacyMealPlansDirectory, includingPropertiesForKeys: nil)
            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }

            for fileURL in jsonFiles {
                let fileName = fileURL.deletingPathExtension().lastPathComponent

                // Read legacy file data
                if let data = try? Data(contentsOf: fileURL),
                   let jsonObject = try? JSONSerialization.jsonObject(with: data) {

                    // Store in new user-scoped format
                    let newKey = "\(userID)_mealplan_\(fileName)"
                    fileSystemBackend.setValue(jsonObject, forKey: newKey)

                    // Remove legacy file
                    try? fileManager.removeItem(at: fileURL)

                    print("📦 [Migration] Migrated meal plan file: \(fileName) -> \(newKey)")
                }
            }

            // Remove legacy directory if empty
            let remainingFiles = try fileManager.contentsOfDirectory(at: legacyMealPlansDirectory, includingPropertiesForKeys: nil)
            if remainingFiles.isEmpty {
                try fileManager.removeItem(at: legacyMealPlansDirectory)
                print("🗑️ [Migration] Removed empty legacy MealPlans directory")
            }

        } catch {
            print("❌ [Migration] Failed to migrate legacy file system data: \(error)")
        }
    }

    private func getMigratedUsers() -> Set<String> {
        guard let data = userDefaultsBackend.getValue(forKey: migrationStatusKey) as? Data,
              let users = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return Set<String>()
        }
        return Set(users)
    }

    private func markMigrationCompleted(for userID: String) {
        var migratedUsers = getMigratedUsers()
        migratedUsers.insert(userID)

        if let data = try? JSONSerialization.data(withJSONObject: Array(migratedUsers)) {
            userDefaultsBackend.setValue(data, forKey: migrationStatusKey)
        }
    }
}