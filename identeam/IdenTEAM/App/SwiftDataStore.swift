import CoreData
import Foundation
import SwiftData

/// Deletes an outdated or unreadable on-disk cache before creating a container.
/// Only call this when no live ModelContainer is using the store.
func deleteSwiftDataStore(at storeURL: URL) throws {
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
    try coordinator.destroyPersistentStore(at: storeURL, type: .sqlite, options: nil)

    // Core Data can leave empty SQLite files behind after destroying the store.
    for path in [storeURL.path, storeURL.path + "-wal", storeURL.path + "-shm"] {
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch CocoaError.fileNoSuchFile {
            // Already removed by Core Data.
        }
    }
}

let localCacheModelTypes: [any PersistentModel.Type] = [
    Team.self, Ident.self, TeamMember.self, TeamWeek.self, User.self, S3Item.self, Comment.self
]

/// Checks the stored schema before SwiftData can automatically migrate it.
/// Only call this during startup, with no live container using the store.
@MainActor
func makeLocalCacheContainer(schema: Schema, configuration: ModelConfiguration) throws -> ModelContainer {
    guard let model = NSManagedObjectModel.makeManagedObjectModel(for: schema) else {
        throw CocoaError(.coderInvalidValue)
    }
    do {
        if FileManager.default.fileExists(atPath: configuration.url.path) {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType, at: configuration.url
            )
            guard model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) else {
                throw CocoaError(.persistentStoreIncompatibleVersionHash)
            }
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    } catch {
        print("Resetting outdated or unreadable local cache:", error)
        try deleteSwiftDataStore(at: configuration.url)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

/// Removes cached objects through the live context without destroying its store.
@MainActor
func clearLocalCache(in context: ModelContext) throws {
    func deleteModels<T: PersistentModel>(_ type: T.Type) throws {
        for model in try context.fetch(FetchDescriptor<T>()) {
            context.delete(model)
        }
    }
    do {
        for type in localCacheModelTypes {
            try deleteModels(type)
        }
        try context.save()
    } catch {
        context.rollback()
        throw error
    }
}
