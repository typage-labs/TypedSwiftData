import Foundation
import SwiftData
import Testing
import TypedSwiftData

@Suite @MainActor struct ModelIDTests {
    @Test func equalityHashingAndRawValue() throws {
        // iOS 17.5 requires a container for this schema before constructing
        // even an uninserted model. Keep this test independent of suite order.
        let container = try makeContainer()
        defer { withExtendedLifetime(container) {} }
        let restaurant = Restaurant(name: "R")
        let id = restaurant.typedID
        #expect(id.rawValue == restaurant.persistentModelID)
        #expect(id == restaurant.typedID)
        #expect(Set([id, restaurant.typedID]).count == 1)
        #expect(id != Restaurant(name: "Another").typedID)
        let customer: ModelID<Customer> = Customer(name: "C").typedID
        #expect(customer.rawValue.entityName == "Customer")
    }

    @Test func identifiersAreSnapshotsAcrossSave() throws {
        let container = try makeContainer()
        let context = makeContext(container)
        let restaurant = Restaurant(name: "R")
        let customer = Customer(name: "C")
        let before = restaurant.typedID
        let customerBefore = customer.typedID
        context.insert(restaurant)
        context.insert(customer)
        #expect(restaurant.typedID == before)
        #expect(customer.typedID == customerBefore)
        try context.save()
        #expect(restaurant.typedID != before)
        #expect(customer.typedID != customerBefore)
        #expect(try matching(before, in: context).isEmpty)
        #expect(try matching(restaurant.typedID, in: context).count == 1)
        #expect(context.registeredModel(for: before) == nil)
    }

    @Test func registeredLookupDelegatesAtEveryLifecycleStage() throws {
        let container = try makeContainer()
        let context = makeContext(container)
        let restaurant = Restaurant(name: "R")
        #expect(context.registeredModel(for: restaurant.typedID) == nil)
        context.insert(restaurant)
        #expect(context.registeredModel(for: restaurant.typedID) === restaurant)
        try context.save()
        let id = restaurant.typedID
        let rawRegistered: Restaurant? = context.registeredModel(for: id.rawValue)
        #expect(context.registeredModel(for: id) === rawRegistered)
        context.delete(restaurant)
        #expect(restaurant.isDeleted)
        #expect(context.registeredModel(for: id) === restaurant)
        #expect(try matching(id, in: context).isEmpty)
        try context.save()
        #expect(context.registeredModel(for: id) == nil)
        #expect(try matching(id, in: context).isEmpty)
    }

    @Test func fetchPreservesDescriptor() throws {
        let container = try makeContainer()
        let context = makeContext(container)
        let saved = ["Alpha", "Bravo", "Charlie", "Delta"].map { Restaurant(name: $0) }
        for restaurant in saved { context.insert(restaurant) }
        context.insert(Customer(name: "Unrelated"))
        try context.save()
        var descriptor = FetchDescriptor<Restaurant>(
            predicate: #Predicate { $0.name != "Alpha" },
            sortBy: [SortDescriptor(\Restaurant.name, order: .reverse)]
        )
        descriptor.fetchOffset = 1
        descriptor.fetchLimit = 2
        descriptor.includePendingChanges = false
        let expected = try context.fetchIdentifiers(descriptor)
        let actual: [ModelID<Restaurant>] = try context.fetchTypedIdentifiers(descriptor)
        #expect(actual.map(\.rawValue) == expected)
        #expect(!actual.isEmpty)
        #expect(actual.allSatisfy { $0.rawValue.entityName == "Restaurant" })
        let customerIDs: [ModelID<Customer>] = try context.fetchTypedIdentifiers(FetchDescriptor<Customer>())
        #expect(customerIDs.count == 1)
    }

    @Test func pendingSortingErrorsAreForwarded() throws {
        let container = try makeContainer()
        let context = makeContext(container)
        context.insert(Restaurant(name: "Pending"))
        let descriptor = FetchDescriptor<Restaurant>(sortBy: [SortDescriptor(\Restaurant.name)])
        #expect(throws: SwiftDataError.sortingPendingChangesWithIdentifiers) {
            try context.fetchIdentifiers(descriptor)
        }
        #expect(throws: SwiftDataError.sortingPendingChangesWithIdentifiers) {
            try context.fetchTypedIdentifiers(descriptor)
        }
    }

    @Test func pendingInsertionAndDeletionAreNative() throws {
        let container = try makeContainer()
        let context = makeContext(container)
        let restaurant = Restaurant(name: "R")
        context.insert(restaurant)
        #expect(try context.fetchTypedIdentifiers(FetchDescriptor<Restaurant>()) == [restaurant.typedID])
        try context.save()
        let id = restaurant.typedID
        context.delete(restaurant)
        #expect(try context.fetchTypedIdentifiers(FetchDescriptor<Restaurant>()).isEmpty)
        var stored = FetchDescriptor<Restaurant>()
        stored.includePendingChanges = false
        #expect(try context.fetchTypedIdentifiers(stored) == [id])
        try context.save()
        #expect(try context.fetchTypedIdentifiers(stored).isEmpty)
    }

    @Test func twoContextsShareSavedIdentityButNotInstances() throws {
        let container = try makeContainer()
        let writer = makeContext(container)
        let reader = makeContext(container)
        let restaurant = Restaurant(name: "R")
        writer.insert(restaurant)
        #expect(try reader.fetchTypedIdentifiers(FetchDescriptor<Restaurant>()).isEmpty)
        try writer.save()
        let id = restaurant.typedID
        #expect(reader.registeredModel(for: id) == nil)
        let fetched = try #require(matching(id, in: reader).first)
        #expect(fetched !== restaurant)
        #expect(fetched.typedID == id)
        #expect(reader.registeredModel(for: id) === fetched)
        writer.delete(restaurant)
        #expect(try matching(id, in: reader).count == 1)
        try writer.save()
        // The cache can retain the object after another context deletes the row.
        #expect(reader.registeredModel(for: id) === fetched)
        #expect(try matching(id, in: reader).isEmpty)
    }

    @Test func unrelatedContainersDoNotResolveEachOthersIDs() throws {
        let first = try makeContainer()
        let second = try makeContainer()
        let a = makeContext(first)
        let b = makeContext(second)
        let ra = Restaurant(name: "A")
        let rb = Restaurant(name: "B")
        a.insert(ra)
        b.insert(rb)
        try a.save()
        try b.save()
        #expect(ra.typedID != rb.typedID)
        #expect(b.registeredModel(for: ra.typedID) == nil)
        #expect(try matching(ra.typedID, in: b).isEmpty)
        #expect(try b.fetchTypedIdentifiers(FetchDescriptor<Restaurant>()) == [rb.typedID])
    }

    @Test func nativeModelForCanManufactureDeletedModel() throws {
        let container = try makeContainer()
        let writer = makeContext(container)
        let restaurant = Restaurant(name: "R")
        writer.insert(restaurant)
        try writer.save()
        let id = restaurant.typedID
        writer.delete(restaurant)
        try writer.save()
        let reader = makeContext(container)
        #expect(try matching(id, in: reader).isEmpty)
        let placeholder = reader.model(for: id.rawValue)
        #expect(placeholder is Restaurant)
        #expect(placeholder.persistentModelID == id.rawValue)
        #expect(reader.registeredModel(for: id) != nil)
        // Do not access placeholder.name here; the isolated probe tests the trap.
    }

    @Test func identifiersCrossModelActorsAndOrdinaryActors() async throws {
        let container = try makeContainer()
        let writer = RestaurantWorker(modelContainer: container)
        let reader = RestaurantWorker(modelContainer: container)
        let mailbox = IdentifierMailbox()
        let id = try await writer.insert(name: "Actor restaurant")
        await mailbox.store(id)
        #expect(await mailbox.contains(id))
        #expect(try await reader.name(for: id) == "Actor restaurant")
        #expect(try await reader.fetchAndCheckRegistration(for: id))
        #expect(try await reader.identifiers() == [id])
        let detachedID = await Task.detached { id }.value
        #expect(detachedID == id)
        try await writer.delete(id)
        #expect(try await reader.name(for: id) == nil)
    }

    @Test func emptyFetch() throws {
        let container = try makeContainer()
        #expect(try makeContext(container).fetchTypedIdentifiers(FetchDescriptor<Restaurant>()).isEmpty)
    }
}
