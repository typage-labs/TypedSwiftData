import SwiftData
import TypedSwiftData

@available(macOS 26, iOS 26, *)
func inheritance(_ cafe: Cafe, context: ModelContext) throws {
    let childID: ModelID<Cafe> = cafe.typedID
    let base: Venue = cafe
    let baseID: ModelID<Venue> = base.typedID
    let _: Cafe? = context.registeredModel(for: childID)
    let _: Venue? = context.registeredModel(for: baseID)
    let _: [ModelID<Venue>] = try context.fetchTypedIdentifiers(FetchDescriptor<Venue>())
    let _: [ModelID<Cafe>] = try context.fetchTypedIdentifiers(FetchDescriptor<Cafe>())
}
