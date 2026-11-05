# API design — candidate 0.1.0

Decision date: 2026-11-05. Scope: a model-type association around SwiftData's
identifier, not a persistence abstraction. This package is independent of
TypedCoreData.

The [final review](RELEASE_REVIEW.md) adds protocol/inheritance checks and release
conditions. Production signatures remain unchanged from phase 1.

## Compiled public surface

```swift
public struct ModelID<Model: PersistentModel>: Hashable, Sendable {
    public let rawValue: PersistentIdentifier
    internal init(rawValue: PersistentIdentifier)
}

extension PersistentModel {
    public var typedID: ModelID<Self> { get }
}

extension ModelContext {
    public func fetchTypedIdentifiers<Model: PersistentModel>(
        _ descriptor: FetchDescriptor<Model>
    ) throws -> [ModelID<Model>]

    public func registeredModel<Model: PersistentModel>(
        for identifier: ModelID<Model>
    ) -> Model?
}
```

`Hashable` and `Equatable` are synthesized from `rawValue`. `Model` is a phantom
type parameter: no model object is stored, and `Model: Sendable` is not required.
The compiler verifies `Sendable` from the stored `PersistentIdentifier`. No
unchecked conformance is authored in this package. Apple's frameworks and macros
remain responsible for their own implementations.

The package specifies Swift 6 language mode, which enables complete concurrency
checking. Verification additionally passed `-strict-concurrency=complete` and
treated compiler warnings as errors. No unsafe SwiftPM flags are imposed on
consumers. Methods run in the caller's isolation domain; the library creates no
context, actor, task, queue, save, or transaction. Keep models and their contexts
in their proper isolation domain, and pass the identifiers across actors.

## Static guarantees

| Operation | Compiler-enforced association |
| --- | --- |
| `restaurant.typedID` | `ModelID<Restaurant>` |
| `FetchDescriptor<Customer>` → `fetchTypedIdentifiers` | `[ModelID<Customer>]` |
| `registeredModel(for: ModelID<Customer>)` | `Customer?` |
| `ModelID<Customer>` assigned to `ModelID<Restaurant>` | Rejected |
| A customer lookup assigned to `Restaurant?` | Rejected |
| External `ModelID<Restaurant>(rawValue: raw)` | Rejected: internal initializer |
| Mutating `rawValue` | Rejected: immutable property |
| Encoding or decoding `ModelID` | Rejected: no Codable conformance |

These are type relationships in ordinary safe Swift. They do not validate the
contents of a store or prevent callers from deliberately opting into the native
raw-identifier API. In particular, the library does not parse entity names,
reconstruct identifiers, or perform runtime type erasure followed by a cast.

## Native behavior is preserved

### Protocols, inheritance, and inference

The model parameter represents a static Swift type, not an exact dynamic class.
Protocol-constrained functions retain that type:

```swift
func use<T: PersistentModel>(_ model: T, in context: ModelContext) {
    let id: ModelID<T> = model.typedID
    let result: T? = context.registeredModel(for: id)
    // Use result in the context's isolation domain.
    _ = result
}
```

A refining protocol such as `protocol NamedModel: PersistentModel` also works
as a generic constraint. Direct access to `model.typedID` on
`model: any PersistentModel` is rejected because the returned generic value
cannot erase `Self` that way. `use(erasedModel, in: context)` compiles by opening
the existential at the generic call site; the typed ID stays inside that scope.
No `ModelID<any PersistentModel>` type erasure is offered.

SwiftData model inheritance is available starting with iOS/macOS 26. Tests are
availability-gated accordingly. [Apple's inheritance introduction](https://developer.apple.com/videos/play/wwdc2025/291/)

For a `Cafe: Venue`, `cafe.typedID` has type `ModelID<Cafe>`. After explicitly
upcasting the model to `Venue`, its `typedID` has type `ModelID<Venue>`. Those
values contain equal native IDs in the tested case, but the generic wrappers
are invariant: assigning `ModelID<Cafe>` to `ModelID<Venue>` is rejected. A fetch
of `Venue` preserves native polymorphism and may include Cafe rows. This is
not a way to validate an exact dynamic entity class.

The distinct `fetchTypedIdentifiers` name avoids overloading native fetches only
by result type. The `registeredModel` overload is selected by its parameter:
typed ID versus raw `PersistentIdentifier`. The inferred return type is tied to
the typed ID; native raw calls remain unconstrained by that association.

### Lifecycle and forwarding

`typedID` captures the current native value. It does not save a model or upgrade
temporary identifiers. An old copy remains unchanged after `save()` assigns a
different value. A set or dictionary keyed by that copy is not automatically
rekeyed. Reacquire the ID from the saved model when needed.

`fetchTypedIdentifiers` calls `fetchIdentifiers` exactly once with the caller's
descriptor and maps its results. Predicate, ordering, limit, offset, pending
change policy, and errors belong to SwiftData. The observed
`sortingPendingChangesWithIdentifiers` error is forwarded without recovery or
fallback to full-model fetching.

The typed `registeredModel` overload delegates to the native overload taking
`PersistentIdentifier`. It returns the native result, including pending-deleted
or stale registered objects. It does not filter with `isDeleted`; after a saved
deletion, the retained object's flag was observed to reset to false. It also
does not keep objects alive: dropping the last external reference made a reader
context's registration disappear in the probes.

Apple documents `model(for:)` as capable of returning an unsaved instance when
the context does not know the identifier. That operation is not an existence
check. [Apple: model(for:)](https://developer.apple.com/documentation/swiftdata/modelcontext/model(for:))

## Why `existingModel(for:)` is excluded

No public or internal production implementation of `existingModel` was added.
Before making this decision, the standalone experiments used two native
`@Model` types and exercised a concrete and a generic predicate:

```swift
let predicate = #Predicate<T> { $0.persistentModelID == rawID }
let results = try context.fetch(FetchDescriptor<T>(predicate: predicate))
```

This compiles and works for a saved model across two contexts of one container
in the tested environments. It also distinguishes pending deletion from stored
rows when `includePendingChanges` changes. It is therefore more meaningful than
`context.model(for: rawID) as? T`.

It is insufficient for the requested general existence API. After the original
SQLite container and context were released (weak references became nil), opening
the same file produced these results:

- An unfiltered fetch read the saved row and its original name.
- A fetch using the old ID returned zero rows, both concretely and generically.
- A fetch using the newly read ID returned one row.
- Old and new IDs had equal `storeIdentifier` values and the same store/entity/
  row URL in debug descriptions, but native equality returned false.

Two simultaneously alive containers for the same SQLite file reproduced this.
The behavior also reproduced on iOS simulators 18.5 and 27.0. It is recorded as a
SwiftData identity/lookup anomaly, not a proven diagnosis of Apple's internals.
No unsupported conversion of debug URLs or serialized identifiers is used to
work around it.

Returning `nil` from an API named `existingModel` in that situation would confuse
an unresolved identifier with an absent row. A registered-object fast path would
also accept stale or pending-deleted objects. Property access on a placeholder
for a deleted row trapped in the framework; it cannot be caught as a Swift error.
Cross-context deletion can additionally race with later access. A broad
existence guarantee has not been established.

The originally proposed expression
`let r: Restaurant? = try context.existingModel(for: customerID)` is rejected
because that method does not exist in this phase. That is tested explicitly, but
is **not** counted as proof of rejecting a model-type mismatch. The separate
`registeredModel`, fetch-result, and ID-assignment fixtures verify those type
errors against implemented APIs.

## Candidate 0.1.0 scope

Retain `ModelID`, `typedID`, `fetchTypedIdentifiers`, and typed
`registeredModel(for:)`. Their value is compiler-checked model association,
typed collections, and identifier transmission between actors in one container's
normal lifetime.

Exclude `existingModel`, a typed `model(for:)` convenience, Codable,
RawRepresentable, public raw constructors, permanent-ID claims, store validators,
identifier remapping, batch-fetch wrappers, custom macros, and an ORM. None is
necessary to deliver the retained surface.

Do not publish a claim of runtime validation for iOS 17 or macOS 14 until those
systems are actually exercised. Compilation targeting them is recorded
separately from runtime testing. Xcode 26.6 and 27.2 RC passed the hosted checks
recorded in [GitHub CI validation](GITHUB_CI.md).

Recommendation: prepare a small 0.1.0 with the retained surface and these limits;
do not add `existingModel` on the strength of the current results.
