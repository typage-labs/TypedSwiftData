import SwiftData
import TypedSwiftData

func wrong(_ context: ModelContext) throws {
    let _: [ModelID<Restaurant>] = try context.fetchTypedIdentifiers(FetchDescriptor<Customer>()) // expected-error: cannot assign value of type '\[ModelID<Customer>\]' to type '\[ModelID<Restaurant>\]'
}
