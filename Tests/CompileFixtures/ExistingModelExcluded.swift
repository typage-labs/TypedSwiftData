import SwiftData
import TypedSwiftData

// This checks API exclusion, NOT the model-type safety demonstrated in
// WrongRegisteredModel.swift. There is deliberately no existingModel API.
func excluded(_ context: ModelContext, _ customer: Customer) throws {
    let _: Restaurant? = try context.existingModel(for: customer.typedID) // expected-error: value of type 'ModelContext' has no member 'existingModel'
}
