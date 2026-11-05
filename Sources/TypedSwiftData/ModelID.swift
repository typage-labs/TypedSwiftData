import SwiftData

/// A snapshot of a model's native identifier, associated with its model type.
///
/// This value does not prove persistence, existence, or membership in a store.
/// Capture a new value after saving an inserted model: SwiftData can replace
/// its identifier, and copies of the old identifier do not update themselves.
public struct ModelID<Model: PersistentModel>: Hashable, Sendable {
    public let rawValue: PersistentIdentifier

    internal init(rawValue: PersistentIdentifier) {
        self.rawValue = rawValue
    }
}

extension PersistentModel {
    /// The current identifier, associated with this model's static type.
    public var typedID: ModelID<Self> {
        ModelID(rawValue: persistentModelID)
    }
}
