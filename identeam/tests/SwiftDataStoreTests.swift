import Foundation
import SwiftData
import XCTest

@Model
final class StoreTestItem {
    var name: String

    init(name: String) { self.name = name }
}

final class SwiftDataStoreTests: XCTestCase {
    func testResetRecreatesEmptyWritableStoreAndPreservesOtherFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let unrelated = directory.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: unrelated)
        let schema = Schema([StoreTestItem.self])
        let configuration = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("test.store"))

        try autoreleasepool {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            context.insert(StoreTestItem(name: "old"))
            try context.save()
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<StoreTestItem>()), 1)
        }

        try deleteSwiftDataStore(at: configuration.url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: configuration.url.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: configuration.url.path + "-wal"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: configuration.url.path + "-shm"))
        XCTAssertEqual(try Data(contentsOf: unrelated), Data("keep".utf8))

        try autoreleasepool {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<StoreTestItem>()), 0)
            context.insert(StoreTestItem(name: "new"))
            try context.save()
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<StoreTestItem>()), 1)
        }
    }

    func testDeletionErrorsArePropagated() {
        XCTAssertThrowsError(try deleteSwiftDataStore(at: URL(string: "https://example.invalid/test.store")!))
    }
}

@main
struct StoreTestRunner {
    static func main() {
        let suite = SwiftDataStoreTests.defaultTestSuite
        suite.run()
        guard let run = suite.testRun, run.executionCount == 2, run.hasSucceeded else {
            exit(1)
        }
    }
}
