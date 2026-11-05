import Foundation
import SwiftData
import TypedSwiftData

@Model final class Restaurant {
    var name: String
    init(name: String) { self.name = name }
}

@Model final class Customer {
    var name: String
    init(name: String) { self.name = name }
}

@MainActor func makeContainer(url: URL? = nil) throws -> ModelContainer {
    let schema = Schema([Restaurant.self, Customer.self])
    let configuration: ModelConfiguration
    if let url {
        configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    } else {
        configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    }
    return try ModelContainer(for: schema, configurations: [configuration])
}

@MainActor func makeContext(_ container: ModelContainer) -> ModelContext {
    let context = ModelContext(container)
    context.autosaveEnabled = false
    return context
}

// A native query used only in tests, not a public existence API.
func matching<T: PersistentModel>(_ id: ModelID<T>, in context: ModelContext) throws -> [T] {
    let raw = id.rawValue
    return try context.fetch(FetchDescriptor<T>(predicate: #Predicate { $0.persistentModelID == raw }))
}

@ModelActor actor RestaurantWorker {
    func insert(name: String) throws -> ModelID<Restaurant> {
        let restaurant = Restaurant(name: name)
        modelContext.insert(restaurant)
        try modelContext.save()
        return restaurant.typedID
    }

    func name(for id: ModelID<Restaurant>) throws -> String? {
        try matching(id, in: modelContext).first?.name
    }

    func identifiers() throws -> [ModelID<Restaurant>] {
        try modelContext.fetchTypedIdentifiers(FetchDescriptor<Restaurant>())
    }

    func fetchAndCheckRegistration(for id: ModelID<Restaurant>) throws -> Bool {
        guard let model = try matching(id, in: modelContext).first else { return false }
        return withExtendedLifetime(model) {
            modelContext.registeredModel(for: id) === model
        }
    }

    func delete(_ id: ModelID<Restaurant>) throws {
        for model in try matching(id, in: modelContext) { modelContext.delete(model) }
        try modelContext.save()
    }
}

actor IdentifierMailbox {
    private var values: Set<ModelID<Restaurant>> = []
    func store(_ id: ModelID<Restaurant>) { values.insert(id) }
    func contains(_ id: ModelID<Restaurant>) -> Bool { values.contains(id) }
}
