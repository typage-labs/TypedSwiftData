import SwiftData
import TypedSwiftData

func requiresSendable<T: Sendable>(_: T) {}
func requiresHashable<T: Hashable>(_: T) {}

func positive(context: ModelContext, restaurant: Restaurant, customer: Customer) throws {
    let restaurantID: ModelID<Restaurant> = restaurant.typedID
    let customerID: ModelID<Customer> = customer.typedID
    let _: [ModelID<Restaurant>] = try context.fetchTypedIdentifiers(FetchDescriptor<Restaurant>())
    let _: [ModelID<Customer>] = try context.fetchTypedIdentifiers(FetchDescriptor<Customer>())
    let _: Restaurant? = context.registeredModel(for: restaurantID)
    let _: Customer? = context.registeredModel(for: customerID)
    // Native overloads remain available.
    let _: Restaurant? = context.registeredModel(for: restaurantID.rawValue)
    // Before: a raw ID permits an unrelated model type to be requested.
    // This compiles; it does not mean a Restaurant exists for that Customer ID.
    let _: Restaurant? = context.registeredModel(for: customer.persistentModelID)
    // After: inference ties the result to Customer; the wrong assignment is
    // rejected in WrongRegisteredModel.swift.
    let inferredCustomer = context.registeredModel(for: customerID)
    let _: Customer? = inferredCustomer
    let _: any PersistentModel = context.model(for: restaurantID.rawValue)
    let _: [PersistentIdentifier] = try context.fetchIdentifiers(FetchDescriptor<Restaurant>())
    requiresSendable(restaurantID)
    requiresHashable(restaurantID)
    let _: Set<ModelID<Restaurant>> = [restaurantID]
}

@ModelActor actor Worker {
    func identifiers() throws -> [ModelID<Restaurant>] {
        try modelContext.fetchTypedIdentifiers(FetchDescriptor<Restaurant>())
    }

    func registered(_ id: ModelID<Restaurant>) -> Bool {
        modelContext.registeredModel(for: id) != nil
    }
}

func crossesActors(_ first: Worker, _ second: Worker) async throws -> Bool {
    guard let id = try await first.identifiers().first else { return false }
    return await second.registered(id)
}
