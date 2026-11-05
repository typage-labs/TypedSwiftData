import SwiftData
import TypedSwiftData

func wrong(_ raw: PersistentIdentifier) {
    let _ = ModelID<Restaurant>(rawValue: raw) // expected-error: 'ModelID<Model>' initializer is inaccessible due to 'internal' protection level
}
