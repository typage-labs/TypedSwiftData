import Foundation
import SwiftData
import Testing
import TypedSwiftData

@Suite @MainActor struct SQLiteTests {
    @Test func sqliteSaveDeleteAndReopen() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TypedSwiftDataTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.sqlite")
        weak var releasedContainer: ModelContainer?
        weak var releasedContext: ModelContext?
        let oldID: ModelID<Restaurant> = try autoreleasepool {
            let container = try makeContainer(url: url)
            let context = makeContext(container)
            releasedContainer = container
            releasedContext = context
            let restaurant = Restaurant(name: "Persisted")
            context.insert(restaurant)
            try context.save()
            #expect(try context.fetchTypedIdentifiers(FetchDescriptor<Restaurant>()) == [restaurant.typedID])
            return restaurant.typedID
        }
        for _ in 0..<100 {
            if releasedContainer == nil && releasedContext == nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(releasedContainer == nil)
        try #require(releasedContext == nil)
        #expect(String(decoding: try Data(contentsOf: url).prefix(15), as: UTF8.self) == "SQLite format 3")
        try autoreleasepool {
            let container = try makeContainer(url: url)
            let context = makeContext(container)
            let restaurant = try #require(context.fetch(FetchDescriptor<Restaurant>()).first)
            #expect(restaurant.name == "Persisted")
            #expect(try context.fetchTypedIdentifiers(FetchDescriptor<Restaurant>()) == [restaurant.typedID])
            // Compare with the native query, without promising that old IDs survive
            // a container lifetime. The experiments record the SDK/runtime anomaly.
            let raw = oldID.rawValue
            let native = try context.fetch(FetchDescriptor<Restaurant>(predicate: #Predicate { $0.persistentModelID == raw }))
            #expect(try matching(oldID, in: context).map(\.typedID) == native.map(\.typedID))
            #expect(oldID.rawValue.storeIdentifier == restaurant.persistentModelID.storeIdentifier)
            let current = restaurant.typedID
            context.delete(restaurant)
            #expect(context.registeredModel(for: current) === restaurant)
            #expect(try context.fetchTypedIdentifiers(FetchDescriptor<Restaurant>()).isEmpty)
            try context.save()
            #expect(context.registeredModel(for: current) == nil)
        }
        let finalContainer = try makeContainer(url: url)
        #expect(try makeContext(finalContainer).fetchTypedIdentifiers(FetchDescriptor<Restaurant>()).isEmpty)
    }

    @Test func identifiersCrossActorsWithSQLite() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TypedSwiftDataActors-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = try makeContainer(url: directory.appendingPathComponent("test.sqlite"))
        let writer = RestaurantWorker(modelContainer: container)
        let reader = RestaurantWorker(modelContainer: container)
        let id = try await writer.insert(name: "SQLite actor")
        #expect(try await reader.name(for: id) == "SQLite actor")
        #expect(try await reader.identifiers() == [id])
    }
}
