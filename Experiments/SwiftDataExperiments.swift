import Foundation
import SwiftData

// These probes intentionally use only native SwiftData, before an existence API
// is considered. Each potentially fatal scenario runs in a separate process.
@main enum SwiftDataExperiments {
    @MainActor static func main() async {
        do {
            guard let scenario = CommandLine.arguments.dropFirst().first else {
                throw ProbeError.missingScenario
            }
            switch scenario {
            case "lifecycle": try lifecycle()
            case "pending-delete": try pendingDelete()
            case "contexts": try contexts()
            case "containers": try containers()
            case "reopen": try await reopen()
            case "same-store-containers": try sameStoreContainers()
            case "registration-lifetime": try registrationLifetime()
            case "pending-sort": try pendingSort()
            case "generic-predicate": try genericPredicate()
            case "temporary-predicate": try temporaryPredicate()
            case "model-never-inserted", "model-deleted", "model-deleted-property",
                 "model-stale-temporary", "model-foreign": try modelLookup(scenario)
            default: throw ProbeError.unknownScenario(scenario)
            }
            emit("completed", ["scenario": scenario])
        } catch {
            emit("error", ["message": String(describing: error)])
            exit(1)
        }
    }

    enum ProbeError: Error { case missingScenario, unknownScenario(String) }

    static func emit(_ event: String, _ values: [String: Any] = [:]) {
        let record = values.merging(["event": event]) { _, new in new }
        let data = try! JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
        // Write immediately so a subsequent framework trap cannot hide evidence.
        FileHandle.standardOutput.write(data + Data([10]))
    }

    @MainActor static func container(url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([Restaurant.self, Customer.self])
        let config: ModelConfiguration
        if let url {
            config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor static func context(_ container: ModelContainer) -> ModelContext {
        let result = ModelContext(container)
        result.autosaveEnabled = false
        return result
    }

    static func describe(_ id: PersistentIdentifier) -> [String: Any] {
        var result: [String: Any] = ["description": String(describing: id),
                                     "store": id.storeIdentifier ?? "nil", "entity": id.entityName]
        #if SDK_HAS_TEMPORARY_IDENTIFIER
        if #available(macOS 27, iOS 27, *) {
            result["isTemporary"] = id.isTemporary
        }
        #endif
        return result
    }

    @MainActor static func matches(_ id: PersistentIdentifier, in context: ModelContext,
                                   pending: Bool = true) throws -> [Restaurant] {
        var descriptor = FetchDescriptor<Restaurant>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.includePendingChanges = pending
        return try context.fetch(descriptor)
    }

    @MainActor static func genericMatches<T: PersistentModel>(
        _ type: T.Type, id: PersistentIdentifier, in context: ModelContext
    ) throws -> [T] {
        let predicate = #Predicate<T> { $0.persistentModelID == id }
        return try context.fetch(FetchDescriptor<T>(predicate: predicate))
    }

    @MainActor static func lifecycle() throws {
        let container = try container()
        let context = context(container)
        let restaurant = Restaurant(name: "R")
        let customer = Customer(name: "C")
        let before = restaurant.persistentModelID
        let customerBefore = customer.persistentModelID
        emit("before", describe(before))
        emit("customer-before", describe(customerBefore))
        context.insert(restaurant)
        context.insert(customer)
        let inserted = restaurant.persistentModelID
        emit("inserted", describe(inserted))
        emit("inserted-state", ["sameAsBefore": before == inserted,
                                "registered": (context.registeredModel(for: inserted) as Restaurant?) === restaurant,
                                "fetchCount": try context.fetch(FetchDescriptor<Restaurant>()).count,
                                "identifierCount": try context.fetchIdentifiers(FetchDescriptor<Restaurant>()).count])
        try context.save()
        let saved = restaurant.persistentModelID
        emit("saved", describe(saved))
        emit("customer-saved", describe(customer.persistentModelID))
        emit("saved-state", ["sameAsInserted": inserted == saved, "copyStillEqualsBefore": inserted == before,
                             "oldRegistered": (context.registeredModel(for: before) as Restaurant?) != nil,
                             "newRegistered": (context.registeredModel(for: saved) as Restaurant?) === restaurant,
                             "customerChanged": customerBefore != customer.persistentModelID,
                             "fetchCount": try matches(saved, in: context).count,
                             "identifierEqualsSaved": try context.fetchIdentifiers(FetchDescriptor<Restaurant>()) == [saved]])
    }

    @MainActor static func pendingDelete() throws {
        let container = try container()
        let context = context(container)
        let restaurant = Restaurant(name: "R")
        context.insert(restaurant)
        try context.save()
        let id = restaurant.persistentModelID
        context.delete(restaurant)
        emit("pending-delete", ["isDeleted": restaurant.isDeleted,
                                "registered": (context.registeredModel(for: id) as Restaurant?) != nil,
                                "fetchPending": try matches(id, in: context).count,
                                "fetchStored": try matches(id, in: context, pending: false).count,
                                "identifierCount": try context.fetchIdentifiers(FetchDescriptor<Restaurant>()).count,
                                "deletedArray": context.deletedModelsArray.count])
        try context.save()
        emit("saved-delete", ["isDeleted": restaurant.isDeleted,
                              "contextNil": restaurant.modelContext == nil,
                              "registered": (context.registeredModel(for: id) as Restaurant?) != nil,
                              "fetchPending": try matches(id, in: context).count,
                              "fetchStored": try matches(id, in: context, pending: false).count,
                              "identifierCount": try context.fetchIdentifiers(FetchDescriptor<Restaurant>()).count])
    }

    @MainActor static func contexts() throws {
        let container = try container()
        let a = context(container)
        let b = context(container)
        let restaurant = Restaurant(name: "R")
        a.insert(restaurant)
        emit("other-context-unsaved", ["fetchCount": try b.fetch(FetchDescriptor<Restaurant>()).count])
        try a.save()
        let id = restaurant.persistentModelID
        emit("other-context-before-fetch", ["registered": (b.registeredModel(for: id) as Restaurant?) != nil])
        let resolved = try matches(id, in: b)
        emit("other-context-saved", ["fetchCount": resolved.count,
                                     "sameInstance": resolved.first === restaurant,
                                     "sameID": resolved.first?.persistentModelID == id,
                                     "registered": (b.registeredModel(for: id) as Restaurant?) != nil])
        a.delete(restaurant)
        emit("other-context-pending-delete", ["fetchCount": try matches(id, in: b).count])
        try a.save()
        emit("other-context-saved-delete", ["registeredBeforeFetch": (b.registeredModel(for: id) as Restaurant?) != nil,
                                            "fetchCount": try matches(id, in: b).count])
    }

    @MainActor static func containers() throws {
        let a = try container()
        let b = try container()
        let ca = context(a)
        let cb = context(b)
        let ra = Restaurant(name: "A")
        let rb = Restaurant(name: "B")
        ca.insert(ra)
        cb.insert(rb)
        try ca.save()
        try cb.save()
        let id = ra.persistentModelID
        emit("different-containers", ["sameID": id == rb.persistentModelID,
                                      "sameStore": id.storeIdentifier == rb.persistentModelID.storeIdentifier,
                                      "registered": (cb.registeredModel(for: id) as Restaurant?) != nil,
                                      "fetchCount": try matches(id, in: cb).count,
                                      "localCount": try cb.fetch(FetchDescriptor<Restaurant>()).count])
    }

    @MainActor static func reopen() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("TypedSwiftData-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("data.sqlite")
        weak var oldContainer: ModelContainer?
        weak var oldContext: ModelContext?
        let id: PersistentIdentifier = try autoreleasepool {
            let container = try container(url: url)
            let context = context(container)
            oldContainer = container
            oldContext = context
            let restaurant = Restaurant(name: "Reopened")
            context.insert(restaurant)
            try context.save()
            return restaurant.persistentModelID
        }
        // SwiftData can briefly retain a container in work scheduled by save().
        // Yield for that work, then report actual weak-reference state; never
        // treat leaving the lexical scope alone as proof of closure.
        for _ in 0..<100 {
            if oldContainer == nil && oldContext == nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        emit("released", ["containerNil": oldContainer == nil, "contextNil": oldContext == nil,
                          "sqliteHeader": String(decoding: try Data(contentsOf: url).prefix(15), as: UTF8.self)])
        let reopened = try container(url: url)
        let reader = context(reopened)
        let result = try matches(id, in: reader)
        emit("reopened", ["count": result.count, "name": result.first?.name ?? "nil",
                          "sameID": result.first?.persistentModelID == id])
        let all = try reader.fetch(FetchDescriptor<Restaurant>())
        if let first = all.first {
            let current = first.persistentModelID
            emit("reopened-row", ["allCount": all.count, "name": first.name,
                                  "sameID": id == current, "sameInnerID": id.id == current.id,
                                  "sameHash": id.hashValue == current.hashValue,
                                  "sameStore": id.storeIdentifier == current.storeIdentifier,
                                  "oldIDFetchCount": try matches(id, in: reader).count,
                                  "newIDFetchCount": try matches(current, in: reader).count,
                                  "oldIDGenericFetchCount": try genericMatches(Restaurant.self, id: id, in: reader).count,
                                  "oldIDRegistered": (reader.registeredModel(for: id) as Restaurant?) != nil,
                                  "newIDRegistered": (reader.registeredModel(for: current) as Restaurant?) != nil])
            emit("old-id", describe(id))
            emit("new-id", describe(current))
        }
    }

    @MainActor static func sameStoreContainers() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("TypedSwiftData-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("data.sqlite")
        let a = try container(url: url)
        let ca = context(a)
        let restaurant = Restaurant(name: "Shared file")
        ca.insert(restaurant)
        try ca.save()
        let id = restaurant.persistentModelID
        let b = try container(url: url)
        let cb = context(b)
        let matchesOld = try matches(id, in: cb)
        let all = try cb.fetch(FetchDescriptor<Restaurant>())
        emit("same-store-containers", ["oldIDFetchCount": matchesOld.count,
                                       "allCount": all.count,
                                       "sameID": all.first?.persistentModelID == id,
                                       "sameStore": all.first?.persistentModelID.storeIdentifier == id.storeIdentifier])
    }

    @MainActor static func genericPredicate() throws {
        let container = try container()
        let context = context(container)
        let restaurant = Restaurant(name: "R")
        context.insert(restaurant)
        try context.save()
        let id = restaurant.persistentModelID
        emit("generic-before-fetch")
        emit("generic-result", ["count": try genericMatches(Restaurant.self, id: id, in: context).count,
                                "wrongEntityCount": try genericMatches(Customer.self, id: id, in: context).count])
    }

    @MainActor static func temporaryPredicate() throws {
        let container = try container()
        let context = context(container)
        let restaurant = Restaurant(name: "R")
        let old = restaurant.persistentModelID
        emit("never-inserted-fetch", ["count": try matches(old, in: context).count])
        context.insert(restaurant)
        emit("temporary-fetch", ["count": try matches(old, in: context).count,
                                 "storedCount": try matches(old, in: context, pending: false).count])
        try context.save()
        emit("stale-temporary-fetch", ["count": try matches(old, in: context).count,
                                       "currentCount": try matches(restaurant.persistentModelID, in: context).count])
    }

    @MainActor static func registrationLifetime() throws {
        let container = try container()
        let writer = context(container)
        let restaurant = Restaurant(name: "R")
        writer.insert(restaurant)
        try writer.save()
        let id = restaurant.persistentModelID
        let reader = context(container)
        try autoreleasepool {
            let found = try matches(id, in: reader)
            emit("registration-retained", ["registered": (reader.registeredModel(for: id) as Restaurant?) != nil])
            withExtendedLifetime(found) {}
        }
        emit("registration-released", ["registered": (reader.registeredModel(for: id) as Restaurant?) != nil])
    }

    @MainActor static func pendingSort() throws {
        let container = try container()
        let context = context(container)
        context.insert(Restaurant(name: "Pending"))
        do {
            let ids = try context.fetchIdentifiers(FetchDescriptor<Restaurant>(sortBy: [SortDescriptor(\Restaurant.name)]))
            emit("pending-sort", ["count": ids.count, "throwsExpectedError": false])
        } catch {
            emit("pending-sort", ["throwsExpectedError": (error as? SwiftDataError) == .sortingPendingChangesWithIdentifiers,
                                  "error": String(describing: error)])
        }
    }

    @MainActor static func modelLookup(_ scenario: String) throws {
        let container = try container()
        let writer = context(container)
        let restaurant = Restaurant(name: "R")
        var id = restaurant.persistentModelID
        if scenario != "model-never-inserted" {
            writer.insert(restaurant)
            try writer.save()
            if scenario != "model-stale-temporary" { id = restaurant.persistentModelID }
            if scenario.hasPrefix("model-deleted") {
                writer.delete(restaurant)
                try writer.save()
            }
        }
        let readerContainer = try scenario == "model-foreign" ? self.container() : container
        let reader = context(readerContainer)
        emit("before-model-for", ["scenario": scenario,
                                  "registered": (reader.registeredModel(for: id) as Restaurant?) != nil,
                                  "fetchCount": try matches(id, in: reader).count])
        let model = reader.model(for: id)
        emit("after-model-for", ["castsToRestaurant": model is Restaurant,
                                 "sameID": model.persistentModelID == id,
                                 "registered": (reader.registeredModel(for: id) as Restaurant?) != nil])
        if scenario == "model-deleted-property", let restaurant = model as? Restaurant {
            emit("before-property-access")
            emit("property", ["name": restaurant.name])
        }
    }
}
