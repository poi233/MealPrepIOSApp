//
//  CoreDataManager.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/21/25.
//

import CoreData
import Foundation
import SwiftUI

// MARK: - Core Data Manager
class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()

    private var isInitialized = false

    // MARK: - Container
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "MealPrepDataModel")

        // Configure container for performance
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Add error handling for store loading
        let group = DispatchGroup()
        var loadError: Error?

        group.enter()
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
                loadError = error
            }
            group.leave()
        }

        // Wait for store to load (with timeout)
        _ = group.wait(timeout: .now() + 10)

        if let error = loadError {
            fatalError("Core Data failed to load: \(error.localizedDescription)")
        }

        // Enable automatic merging
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Mark as initialized
        self.isInitialized = true

        return container
    }()

    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    // MARK: - Background Context
    func newBackgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }

    // MARK: - Save Context
    func save() async throws {
        try await MainActor.run {
            guard context.hasChanges else { return }

            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
                throw CoreDataError.saveError(error)
            }
        }
    }

    func saveBackground(_ backgroundContext: NSManagedObjectContext) async throws {
        guard backgroundContext.hasChanges else { return }

        try await backgroundContext.perform {
            do {
                try backgroundContext.save()
            } catch {
                print("Failed to save background context: \(error)")
                throw CoreDataError.saveError(error)
            }
        }
    }

    // MARK: - Batch Operations
    func batchDelete<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate? = nil) async throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: type))
        request.predicate = predicate

        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        batchDeleteRequest.resultType = .resultTypeObjectIDs

        let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
        let objectIDArray = result?.result as? [NSManagedObjectID]
        let changes = [NSDeletedObjectsKey: objectIDArray]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes as [AnyHashable: Any], into: [context])
    }

    // MARK: - Fetch Operations
    func fetch<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor] = []) async throws -> [T] {
        // Ensure CoreData is initialized
        _ = persistentContainer

        return try await MainActor.run { [predicate, sortDescriptors] in
            let request = NSFetchRequest<T>(entityName: String(describing: type))
            request.predicate = predicate
            request.sortDescriptors = sortDescriptors

            return try context.fetch(request)
        }
    }

    func fetchFirst<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate? = nil) async throws -> T? {
        // Ensure CoreData is initialized
        _ = persistentContainer

        return try await MainActor.run { [predicate] in
            let request = NSFetchRequest<T>(entityName: String(describing: type))
            request.predicate = predicate
            request.fetchLimit = 1

            return try context.fetch(request).first
        }
    }

    func count<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate? = nil) async throws -> Int {
        return try await MainActor.run { [predicate] in
            let request = NSFetchRequest<T>(entityName: String(describing: type))
            request.predicate = predicate

            return try context.count(for: request)
        }
    }

    // MARK: - Delete Operations
    func delete(_ object: NSManagedObject) {
        context.delete(object)
    }

    func deleteAll<T: NSManagedObject>(_ type: T.Type) async throws {
        try await batchDelete(type)
    }
}

// MARK: - Core Data Errors
enum CoreDataError: LocalizedError {
    case saveError(Error)
    case fetchError(Error)
    case deleteError(Error)
    case modelNotFound

    var errorDescription: String? {
        switch self {
        case .saveError(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .fetchError(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .deleteError(let error):
            return "Failed to delete data: \(error.localizedDescription)"
        case .modelNotFound:
            return "Core Data model not found"
        }
    }
}

// MARK: - Cache Management Protocol
protocol CacheManager {
    associatedtype Entity: NSManagedObject
    associatedtype Model: Codable

    func save(_ models: [Model]) async throws
    func fetch() async throws -> [Model]
    func fetchById(_ id: String) async throws -> Model?
    func update(_ model: Model) async throws
    func delete(_ id: String) async throws
    func deleteAll() async throws
}

// MARK: - Recipe Cache Manager
class RecipeCacheManager: CacheManager {
    typealias Entity = CachedRecipe
    typealias Model = Recipe

    private let coreData = CoreDataManager.shared

    func save(_ recipes: [Recipe]) async throws {
        let backgroundContext = coreData.newBackgroundContext()

        await backgroundContext.perform {
            for recipe in recipes {
                let cachedRecipe = CachedRecipe(context: backgroundContext)
                cachedRecipe.fromRecipe(recipe)
            }
        }

        try await coreData.saveBackground(backgroundContext)
    }

    func fetch() async throws -> [Recipe] {
        let cachedRecipes: [CachedRecipe] = try await coreData.fetch(
            CachedRecipe.self,
            sortDescriptors: [NSSortDescriptor(keyPath: \CachedRecipe.createdAt, ascending: false)]
        )

        return cachedRecipes.compactMap { $0.toRecipe() }
    }

    func fetchById(_ id: String) async throws -> Recipe? {
        let cachedRecipe: CachedRecipe? = try await coreData.fetchFirst(
            CachedRecipe.self,
            predicate: NSPredicate(format: "id == %@", id)
        )

        return cachedRecipe?.toRecipe()
    }

    func update(_ recipe: Recipe) async throws {
        let cachedRecipe: CachedRecipe? = try await coreData.fetchFirst(
            CachedRecipe.self,
            predicate: NSPredicate(format: "id == %@", recipe.id)
        )

        if let cachedRecipe = cachedRecipe {
            cachedRecipe.fromRecipe(recipe)
            try await coreData.save()
        } else {
            try await save([recipe])
        }
    }

    func delete(_ id: String) async throws {
        let cachedRecipe: CachedRecipe? = try await coreData.fetchFirst(
            CachedRecipe.self,
            predicate: NSPredicate(format: "id == %@", id)
        )

        if let cachedRecipe = cachedRecipe {
            coreData.delete(cachedRecipe)
            try await coreData.save()
        }
    }

    func deleteAll() async throws {
        try await coreData.batchDelete(CachedRecipe.self)
    }

    // MARK: - Search and Filter
    func searchRecipes(query: String) async throws -> [Recipe] {
        let predicate = NSPredicate(format: "name CONTAINS[cd] %@ OR recipeDescription CONTAINS[cd] %@", query, query)
        let cachedRecipes: [CachedRecipe] = try await coreData.fetch(
            CachedRecipe.self,
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(keyPath: \CachedRecipe.avgRating, ascending: false)]
        )

        return cachedRecipes.compactMap { $0.toRecipe() }
    }

    func fetchRecipesByDifficulty(_ difficulty: Difficulty) async throws -> [Recipe] {
        let predicate = NSPredicate(format: "difficulty == %@", difficulty.rawValue)
        let cachedRecipes: [CachedRecipe] = try await coreData.fetch(
            CachedRecipe.self,
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(keyPath: \CachedRecipe.createdAt, ascending: false)]
        )

        return cachedRecipes.compactMap { $0.toRecipe() }
    }

    func fetchRecipesByCuisine(_ cuisine: String) async throws -> [Recipe] {
        let predicate = NSPredicate(format: "cuisine == %@", cuisine)
        let cachedRecipes: [CachedRecipe] = try await coreData.fetch(
            CachedRecipe.self,
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(keyPath: \CachedRecipe.createdAt, ascending: false)]
        )

        return cachedRecipes.compactMap { $0.toRecipe() }
    }
}

// MARK: - User Cache Manager
class UserCacheManager: CacheManager {
    typealias Entity = CachedUser
    typealias Model = User

    private let coreData = CoreDataManager.shared

    func save(_ users: [User]) async throws {
        let backgroundContext = coreData.newBackgroundContext()

        await backgroundContext.perform {
            for user in users {
                let cachedUser = CachedUser(context: backgroundContext)
                cachedUser.fromUser(user)
            }
        }

        try await coreData.saveBackground(backgroundContext)
    }

    func fetch() async throws -> [User] {
        let cachedUsers: [CachedUser] = try await coreData.fetch(CachedUser.self)
        return cachedUsers.compactMap { $0.toUser() }
    }

    func fetchById(_ id: String) async throws -> User? {
        let cachedUser: CachedUser? = try await coreData.fetchFirst(
            CachedUser.self,
            predicate: NSPredicate(format: "id == %@", id)
        )

        return cachedUser?.toUser()
    }

    func update(_ user: User) async throws {
        let cachedUser: CachedUser? = try await coreData.fetchFirst(
            CachedUser.self,
            predicate: NSPredicate(format: "id == %@", user.id)
        )

        if let cachedUser = cachedUser {
            cachedUser.fromUser(user)
            try await coreData.save()
        } else {
            try await save([user])
        }
    }

    func delete(_ id: String) async throws {
        let cachedUser: CachedUser? = try await coreData.fetchFirst(
            CachedUser.self,
            predicate: NSPredicate(format: "id == %@", id)
        )

        if let cachedUser = cachedUser {
            coreData.delete(cachedUser)
            try await coreData.save()
        }
    }

    func deleteAll() async throws {
        try await coreData.batchDelete(CachedUser.self)
    }

    // MARK: - Current User Management
    func saveCurrentUser(_ user: User) async throws {
        // Clear existing current user
        let currentUser: CachedUser? = try await coreData.fetchFirst(
            CachedUser.self,
            predicate: NSPredicate(format: "isCurrentUser == TRUE")
        )

        if let currentUser = currentUser {
            currentUser.isCurrentUser = false
        }

        // Find or create the user
        let existingUser: CachedUser? = try await coreData.fetchFirst(
            CachedUser.self,
            predicate: NSPredicate(format: "id == %@", user.id)
        )

        let cachedUser: CachedUser
        if let existingUser = existingUser {
            cachedUser = existingUser
            cachedUser.fromUser(user)
        } else {
            cachedUser = CachedUser(context: coreData.context)
            cachedUser.fromUser(user)
        }

        cachedUser.isCurrentUser = true

        // Save only once
        try await coreData.save()
    }

    func getCurrentUser() async throws -> User? {
        let currentUser: CachedUser? = try await coreData.fetchFirst(
            CachedUser.self,
            predicate: NSPredicate(format: "isCurrentUser == TRUE")
        )

        return currentUser?.toUser()
    }

    func clearCurrentUser() async throws {
        let currentUser: CachedUser? = try await coreData.fetchFirst(
            CachedUser.self,
            predicate: NSPredicate(format: "isCurrentUser == TRUE")
        )

        if let currentUser = currentUser {
            currentUser.isCurrentUser = false
            try await coreData.save()
        }
    }
}