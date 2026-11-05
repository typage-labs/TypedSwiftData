import SwiftData
import Testing
import TypedSwiftData

private protocol NamedModel: PersistentModel { var name: String { get } }
extension Restaurant: NamedModel {}

private func identity<T: NamedModel>(_ model: T) -> ModelID<T> { model.typedID }

private func checkOpened<T: PersistentModel>(_ model: T, in context: ModelContext) -> Bool {
    let id: ModelID<T> = model.typedID
    return context.registeredModel(for: id) === model
}

@available(macOS 26, iOS 26, *)
@Model class Venue {
    var name: String
    init(name: String) { self.name = name }
}

@available(macOS 26, iOS 26, *)
@Model final class Cafe: Venue {
    var seats: Int
    init(name: String, seats: Int) {
        self.seats = seats
        super.init(name: name)
    }
}

@Suite @MainActor struct TypeShapeTests {
    @Test func protocolConstraintsAndOpenedExistential() throws {
        let container = try makeContainer()
        let context = makeContext(container)
        let restaurant = Restaurant(name: "Generic")
        context.insert(restaurant)
        try context.save()
        #expect(identity(restaurant) == restaurant.typedID)
        let erased: any PersistentModel = restaurant
        // Keep implicit existential opening outside the assertion macro's
        // generated closure, which otherwise changes the generic call shape.
        let opened = checkOpened(erased, in: context)
        #expect(opened)
    }

    @Test
    @available(macOS 26, iOS 26, *)
    func inheritancePreservesStaticTypeAndNativePolymorphism() throws {
        let schema = Schema([Venue.self, Cafe.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = makeContext(container)
        let cafe = Cafe(name: "Subclass", seats: 12)
        context.insert(cafe)
        try context.save()
        let base: Venue = cafe
        let childID: ModelID<Cafe> = cafe.typedID
        let baseID: ModelID<Venue> = base.typedID
        #expect(childID.rawValue == baseID.rawValue)
        #expect(context.registeredModel(for: childID) === cafe)
        #expect(context.registeredModel(for: baseID) === base)
        let descriptor = FetchDescriptor<Venue>()
        let nativeIDs = try context.fetchIdentifiers(descriptor)
        let typedIDs: [ModelID<Venue>] = try context.fetchTypedIdentifiers(descriptor)
        #expect(typedIDs.map(\.rawValue) == nativeIDs)
        #expect(typedIDs == [baseID])
        #expect(try context.fetchTypedIdentifiers(FetchDescriptor<Cafe>()) == [childID])
    }
}
