import CoreData
import Foundation

/// Deletes the on-disk store before recreating a container after a load failure.
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
