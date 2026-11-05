import SwiftData

extension ModelContext {
    /// Fetches native identifiers and associates them with the descriptor's type.
    ///
    /// The descriptor, pending-change behavior, ordering, and errors are handled
    /// by SwiftData's `fetchIdentifiers(_:)` without alteration.
    public func fetchTypedIdentifiers<Model: PersistentModel>(
        _ descriptor: FetchDescriptor<Model>
    ) throws -> [ModelID<Model>] {
        try fetchIdentifiers(descriptor).map { ModelID(rawValue: $0) }
    }

    /// Looks in SwiftData's registration cache using the identifier's type.
    ///
    /// A result is not proof that a row still exists. This delegates directly to
    /// SwiftData and does not fetch, filter deleted models, or validate a store.
    public func registeredModel<Model: PersistentModel>(
        for identifier: ModelID<Model>
    ) -> Model? {
        registeredModel(for: identifier.rawValue)
    }
}
