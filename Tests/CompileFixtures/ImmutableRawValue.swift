import SwiftData
import TypedSwiftData

func wrong(_ restaurant: Restaurant, _ raw: PersistentIdentifier) {
    var id = restaurant.typedID
    id.rawValue = raw // expected-error: cannot assign to property: 'rawValue' is a 'let' constant
}
