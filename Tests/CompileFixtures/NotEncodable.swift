import Foundation
import TypedSwiftData

func wrong(_ restaurant: Restaurant) throws {
    let _ = try JSONEncoder().encode(restaurant.typedID) // expected-error: instance method 'encode' requires that 'ModelID<Restaurant>' conform to 'Encodable'
}
