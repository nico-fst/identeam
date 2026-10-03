import CoreData
import Foundation
import SwiftData

struct SharedModelConfig {
    static let appGroup = "group.de.nicostern.identeam"

    static let schema = Schema(localCacheModelTypes)
    static let config = ModelConfiguration(
        "IdenTEAM", schema: schema, groupContainer: .identifier(appGroup))

    enum StoreClient {
        case app
        case widget
    }
    static func makeContainer(for client: StoreClient) -> ModelContainer {
        do {
            return try ModelContainer(
                for: schema,
                configurations: config
            )
        } catch {
            guard client == .app else {
                fatalError("Widget could not open SwiftData store: \(error)")
            }
            do {  // retry creation in app - models could have been changed
                try deleteSwiftDataStore(at: config.url)
                return try ModelContainer(
                    for: schema,
                    configurations: config
                )
            } catch {
                fatalError("ERROR creating local cache: \(error)")
            }
        }
    }
}

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
    // types and referenced types also have to have widget membership
    Team.self, Ident.self, TeamMember.self, TeamWeek.self, User.self, S3Item.self, Comment.self,
]

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
