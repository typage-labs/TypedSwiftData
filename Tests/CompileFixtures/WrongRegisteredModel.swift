import SwiftData
import TypedSwiftData

func wrong(_ context: ModelContext, _ customer: Customer) {
    let _: Restaurant? = context.registeredModel(for: customer.typedID) // expected-error: cannot assign value of type 'Customer\?' to type 'Restaurant\?'
}
