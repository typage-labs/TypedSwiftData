import Foundation
import TypedSwiftData

func wrong(_ data: Data) throws {
    let _ = try JSONDecoder().decode(ModelID<Restaurant>.self, from: data) // expected-error: instance method 'decode\(_:from:\)' requires that 'ModelID<Restaurant>' conform to 'Decodable'
}
