import Foundation
import SwiftData
import Testing
import TypedSwiftData

@Suite @MainActor struct SQLiteTests {
    @Test func sqliteSaveDeleteAcrossContainers() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TypedSwiftDataTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // SwiftData may retain open stores beyond this test (observed on iOS
        // 17.5). Leave unique system-temporary files for later OS cleanup;
        // unlinking them here can invalidate a live native SQLite connection.
        let url = directory.appendingPathComponent("test.sqlite")
        let oldID: ModelID<Restaurant> = try autoreleasepool {
            let container = try makeContainer(url: url)
            let context = makeContext(container)
            let restaurant = Restaurant(name: "Persisted")
            context.insert(restaurant)
            try context.save()
            #expect(try context.fetchTypedIdentifiers(FetchDescriptor<Restaurant>()) == [restaurant.typedID])
            return restaurant.typedID
        }
        #expect(String(decoding: try Data(contentsOf: url).prefix(15), as: UTF8.self) == "SQLite format 3")
        // This verifies visibility through independent containers, not process
        // restart or deterministic ARC release. check_sqlite_restart.py runs
        // writer, reader/deleter and final reader in separate awaited processes.
        // NativeContainerLifetime.swift separately records weak-reference state.
        try autoreleasepool {
            let container = try makeContainer(url: url)
            let context = makeContext(container)
            let restaurant = try #require(context.fetch(FetchDescriptor<Restaurant>()).first)
            #expect(restaurant.name == "Persisted")
            #expect(try context.fetchTypedIdentifiers(FetchDescriptor<Restaurant>()) == [restaurant.typedID])
            // Compare with the native query, without promising that IDs resolve
            // across containers. Native behavior differs between runtimes.
            let raw = oldID.rawValue
            let native = try context.fetch(FetchDescriptor<Restaurant>(predicate: #Predicate { $0.persistentModelID == raw }))
            #expect(try matching(oldID, in: context).map(\.typedID) == native.map(\.typedID))
            #expect(oldID.rawValue.storeIdentifier == restaurant.persistentModelID.storeIdentifier)
            let current = restaurant.typedID
            context.delete(restaurant)
            #expect(context.registeredModel(for: current) === restaurant)
            #expect(try context.fetchTypedIdentifiers(FetchDescriptor<Restaurant>()).isEmpty)
            var stored = FetchDescriptor<Restaurant>()
            stored.includePendingChanges = false
            #expect(try context.fetchTypedIdentifiers(stored) == [current])
            try context.save()
            #expect(context.registeredModel(for: current) == nil)
        }
        let finalContainer = try makeContainer(url: url)
        #expect(try makeContext(finalContainer).fetchTypedIdentifiers(FetchDescriptor<Restaurant>()).isEmpty)
    }

    @Test func identifiersCrossActorsWithSQLite() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TypedSwiftDataActors-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Actors/native stores can outlive this scope; do not unlink open files.
        let container = try makeContainer(url: directory.appendingPathComponent("test.sqlite"))
        let writer = RestaurantWorker(modelContainer: container)
        let reader = RestaurantWorker(modelContainer: container)
        let id = try await writer.insert(name: "SQLite actor")
        #expect(try await reader.name(for: id) == "SQLite actor")
        #expect(try await reader.identifiers() == [id])
    }
}
