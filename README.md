# TypedSwiftData

Model-typed identifiers for Apple's SwiftData. A small, independent Swift package
with no external dependencies, custom macros, or ORM layer.

**[TypedSwiftData 0.1.0](https://github.com/typage-labs/TypedSwiftData/releases/tag/0.1.0)**
is the first public release by Typage Labs. See the [changelog](CHANGELOG.md)
and [compatibility evidence](docs/COMPATIBILITY.md) for its verified scope.

```swift
import SwiftData
import TypedSwiftData

let restaurant = Restaurant(name: "Chez Swift") // Your @Model type
context.insert(restaurant)
try context.save()

let id: ModelID<Restaurant> = restaurant.typedID
let ids: [ModelID<Restaurant>] = try context.fetchTypedIdentifiers(
    FetchDescriptor<Restaurant>()
)
let registered: Restaurant? = context.registeredModel(for: id)
```

## What the type system adds

Before, a raw SwiftData identifier permits requesting an unrelated model type:

```swift
// Compiles with SwiftData. This is not proof that a Restaurant exists.
let restaurant: Restaurant? = context.registeredModel(for: customer.persistentModelID)
```

After, the identifier determines the result type:

```swift
let customerID: ModelID<Customer> = customer.typedID
let customerAgain = context.registeredModel(for: customerID) // Customer?
let restaurant: Restaurant? = context.registeredModel(for: customerID)
// Rejected: cannot assign Customer? to Restaurant?.

let wrongID: ModelID<Restaurant> = customer.typedID
// Rejected: cannot assign ModelID<Customer> to ModelID<Restaurant>.
```

The compiling example and rejected assignments are checked by external-client
fixtures with diagnostic verification. `ModelID<Model>` is `Hashable` and
`Sendable`, without requiring model instances to be Sendable. Its `rawValue` is
an immutable `PersistentIdentifier`; its initializer is internal to the library.
There is no public raw factory, `RawRepresentable`, or `Codable` conformance.

These guarantees follow the **static model type**. A base-class ID can identify
a subclass instance. Generic functions constrained to `PersistentModel` work;
direct `typedID` access on `any PersistentModel` does not. The [API design](docs/API_DESIGN.md)
explains generic use and availability-gated inheritance.

## What it does not guarantee

- A typed ID does not prove that its model exists.
- It does not prove permanence. Capture a fresh `typedID` after saving a newly
  inserted model; earlier copies can become obsolete.
- It does not guarantee resolution in another container, even for the same
  SQLite file. Native lookup anomalies are recorded in the verification report.
- It is not a durable business identity. Use your application's own identity
  scheme when a key must have meaning beyond SwiftData's identifier lifecycle.
- `registeredModel(for:)` can return `nil` while the model exists in storage. It
  is a cache lookup; a non-nil result can also be pending deletion or stale.
- `Sendable` permits transferring the ID, not a model or context, between actors.
  It does not guarantee freshness when the receiving actor later resolves it.

Native SwiftData APIs remain accessible. The typed overload forwards the native
registration lookup, and `fetchTypedIdentifiers` forwards the descriptor and
errors unchanged. It does not save, filter deleted objects, or fetch full models
as a fallback. Sorted identifier fetches with pending insertions can throw a
native error.

`existingModel(for:)` is deliberately excluded. `model(for:)` can produce a
placeholder whose property access traps after deletion, and the tested ID
predicate does not establish existence across container lifetimes. No workaround
or general existence guarantee is introduced here.

## Compatibility

The manifest declares **Swift 6 language mode**, **iOS 17+**, and **macOS 14+**.
Xcode 26.6 (Swift 6.3.3) and Xcode 27.2 (Swift 6.4.2) passed hosted CI;
Xcode 27.1 (Swift 6.4) was also verified locally.

| Evidence | Actually verified |
| --- | --- |
| Compilation | macOS SDKs 26.5, 27.0 and 27.2 targeting macOS 14; iOS SDKs 26.5, 27.1 and 27.2 targeting iOS 17 |
| Runtime tests | Latest local/CI runs: macOS 26.6.2, 26.7.2 and 27.0.1; iOS simulators 17.5, 18.5, 26.5, 27.0, 27.1 and 27.2 |
| SQLite process restarts | Three phases passed on every runtime in the row above, including both GitHub jobs |
| Inheritance tests | macOS/iOS 26 and 27; gated to macOS/iOS 26+, explicitly skipped on iOS 17.5/18.5 |
| Not verified | iOS 17.0/macOS 14 runtime; other untested patch versions; Swift compiler 6.0; physical iOS hardware; Intel execution |

An old deployment target is not an old-runtime test. See the detailed
[compatibility matrix](docs/COMPATIBILITY.md) and [final review](docs/RELEASE_REVIEW.md).
The [SQLite validation](docs/SQLITE_RUNTIME_VALIDATION.md) records local tests;
the [CI report](docs/GITHUB_CI.md) records hosted executions. Native container retention on
iOS 17.5 does not prevent the tested saved data/deletions surviving process exit;
the library promises no container deallocation timing.

## Installation

Add the public package and its library product to your package manifest:

```swift
// dependencies:
.package(url: "https://github.com/typage-labs/TypedSwiftData.git", exact: "0.1.0")

// your target's dependencies:
.product(name: "TypedSwiftData", package: "TypedSwiftData")
```

In Xcode, add `https://github.com/typage-labs/TypedSwiftData.git` as a package
dependency and select version `0.1.0`.

## Verification

With a compatible Xcode and an installed iOS simulator:

```sh
bash Scripts/verify.sh
```

This runs strict Swift 6 tests, positive/negative client compilation, an actual
iOS device build, native probes in isolated processes, simulator tests, and
required SQLite checks across three separate processes on macOS and iOS. It
selects an available recent iPhone simulator, or accepts
`TYPED_SWIFTDATA_SIMULATOR=<UDID>`. It does not claim that this choice tests the
oldest deployment target. Logs go to `.build/verification`; portable historical
summaries are retained in the documentation.

Individual checks:

```sh
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
python3 Scripts/check_compilation.py
python3 Scripts/check_compilation.py --sdk iphoneos --target arm64-apple-ios17.0 --label ios
swift build --product SwiftDataExperiments
python3 Scripts/run_experiments.py
python3 Scripts/check_sqlite_restart.py --label macos --lifetime
```

Negative compilation checks require the intended diagnostic, file, and line;
an arbitrary failure never passes. Native probes include a deliberate SwiftData
`SIGTRAP`, whose specific diagnostic is checked even in observation mode. Add
`--verify-reference` to compare all recorded fields against the reference
environments; a matched native anomaly is not evidence of correct resolution.
The SQLite process check obtains fresh IDs in each process; it does not test
ID serialization or promise that IDs remain meaningful across launches.

The experimental logger can use `isTemporary` only when built with
`-Xswiftc -DSDK_HAS_TEMPORARY_IDENTIFIER` against a 27 SDK, and only inside its
runtime availability guard. Production code does not use that property.

The two GitHub jobs use the same script with explicitly selected Xcode 27 and
26.6. See [observed CI results](docs/GITHUB_CI.md) and
[release conditions](docs/RELEASE_CHECKLIST.md).

## Design, related work, and license

Read [API design](docs/API_DESIGN.md), the [phase 1 evidence](docs/IMPLEMENTATION_VERIFICATION.md),
the [review and comparison](docs/RELEASE_REVIEW.md), and the [changelog](CHANGELOG.md).
Typed identifiers are an established pattern; this package's focus is a small
SwiftData surface with explicit limits and reproducible validation.

Copyright 2026 TypedSwiftData contributors. Licensed under the
[Apache License, Version 2.0](LICENSE). No third-party implementation was imported.
