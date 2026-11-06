# Implementation verification — phase 1

This is the preserved **phase 1** record. The subsequent [final review](RELEASE_REVIEW.md)
contains the updated test inventory, clean-checkout run, classification of native
observations, and its historical publication verdict. The current
[compatibility matrix](COMPATIBILITY.md) separates SDK compilation from
runtime/compiler/Xcode coverage; current release information is in the
[README](../README.md). Statements below describe the phase 1 checkpoint.

Executed on **2026-11-05**, Europe/Paris. This report distinguishes compilation,
runtime assertions, and native observations. No GitHub repository, push, tag, or
release was created. Work stayed in `~/Dev/TypedSwiftData`; no TypedCoreData files
were accessed or changed.

## Decision and implementation

The public library contains `ModelID<Model>: Hashable, Sendable`, an immutable
`rawValue`, `PersistentModel.typedID`, `fetchTypedIdentifiers`, and the typed
`registeredModel(for:)` overload. The raw-value initializer is internal. The
exact compiled declarations and contracts are in [API_DESIGN.md](API_DESIGN.md).

`existingModel(for:)` is excluded. Native existence experiments were executed
before this decision; no production existence implementation was introduced.
The SQLite anomaly below prevents the requested general interpretation of that
name. Casting a result of `model(for:)` was experimentally shown to be inadequate.

There are no external package dependencies, custom macros, authored unchecked
Sendable conformances, Codable conformance, raw public factories, or ORM layer.
Swift 6 mode is set in the manifest; verification explicitly enabled complete
concurrency checking and treated compiler warnings as errors.

## Environment actually used

| Component | Observed value |
| --- | --- |
| Host | arm64, macOS 27.0.1, build 26A434 |
| Xcode | 27.1, build 27A9275 |
| Swift | Apple Swift 6.4, swiftlang-6.4.0.34.1, Swift language mode 6 |
| Xcode macOS SDK | 27.0 |
| Additional SDK | Command Line Tools macOS 26.5 |
| iPhoneOS / simulator SDK | 27.1 |
| Executed iOS runtimes | Simulator iOS 27.0 (24A434) and iOS 18.5 (22F77) |
| Deployment targets compiled | macOS 14.0 and iOS 17.0 |

See [environment.txt — local evidence](evidence/README.md). The actual device build output
was inspected using `vtool`: platform **IOS**, minimum OS **17.0**, SDK **27.1**.
This is an iOS compilation, not an inference from a successful macOS build.

The standalone 26.5 SDK required the Apple SwiftData macro plugin and plugin
server from Xcode 27.1 to compile the `@Model` fixtures. The library itself needs
no macro plugin. This comparison uses **one Swift compiler** and, for the macOS
executables, **one runtime**; it is not an Xcode 26.6 or macOS 26.5 runtime test.

## Phase 1 executed checks

| Check | Exact final result | Evidence |
| --- | --- | --- |
| `swift test`, macOS 27.0.1 | **13 tests, 2 suites, 0 failures**, exit 0 | [log — local evidence](evidence/README.md) |
| Xcode tests, iOS 27.0 simulator | **13 tests, 2 suites, 0 failures**, `TEST SUCCEEDED`, exit 0 | [log — local evidence](evidence/README.md) |
| Same test build, iOS 18.5 simulator | **13 tests, 2 suites, 0 failures**, `TEST EXECUTE SUCCEEDED`, exit 0 | [log — local evidence](evidence/README.md) |
| Device build, iOS 17 target / SDK 27.1 | `BUILD SUCCEEDED`, exit 0 | [log — local evidence](evidence/README.md) |
| External compilation, macOS SDK 27.0 | Library + 1 positive fixture + 8 negative fixtures verified; 0 harness failures | [JSON — local evidence](evidence/README.md) |
| External compilation, macOS SDK 26.5 | Same 10 compiler invocations verified; 0 harness failures | [JSON — local evidence](evidence/README.md) |
| External compilation, iPhoneOS SDK 27.1 | Same 10 compiler invocations verified; 0 harness failures | [JSON — local evidence](evidence/README.md) |
| Native probes, SDK 27 / macOS 27.0.1 | **15/15 reference checks matched** | [JSON — local evidence](evidence/README.md) |
| Native probes, SDK 26.5 / macOS 27.0.1 | **15/15 reference checks matched** | [JSON — local evidence](evidence/README.md) |
| Native probes, SDK 27.1 / iOS 27.0 | **15/15 reference checks matched** | [JSON — local evidence](evidence/README.md) |
| Native probes, SDK 27.1 / iOS 18.5 | **15/15 reference checks matched** | [JSON — local evidence](evidence/README.md) |

The final runtime matrix contains **39 test executions**. The compiler matrix
contains **3 positive client checks and 24 negative checks**, plus 3 library
module compilations. Native probes are counted separately: **60 executions**,
including **4 deliberately trapped processes**. A matched anomaly or expected
trap is not reported as correct native existence behavior.

Each native batch has 14 processes exiting 0 and one deleted-property probe
terminating with `SIGTRAP` (signal 5). Python reports the latter as `-5` on macOS;
`simctl spawn` returns `133` and explicitly reports child signal 5 on iOS. The
harness verifies both the pre-access event and the invalidated-backing-data
diagnostic. It does not accept an arbitrary nonzero exit as the expected trap.

The XCTest compatibility runner prints “Executed 0 tests” before Swift Testing
starts. The 13-test counts above come from the subsequent **Swift Testing** run,
not that empty XCTest section. Xcode also printed an SDK build-number parsing
diagnostic (`invalidDigitCount(94232)`); compilation and test actions completed
successfully, as recorded in their logs.

## Compiler checks and static guarantees

All fixtures import the library normally, without `@testable`. The positive
fixture checks inferred and explicit model types, native-overload coexistence,
Hashable, Sendable without making the models Sendable, and async use across two
`@ModelActor` instances.

| Negative fixture | Required diagnostic reason |
| --- | --- |
| `WrongAssignment.swift` | Cannot assign `ModelID<Customer>` to `ModelID<Restaurant>` |
| `WrongRegisteredModel.swift` | Cannot assign `Customer?` to `Restaurant?` |
| `WrongFetchDescriptor.swift` | Cannot assign `[ModelID<Customer>]` to `[ModelID<Restaurant>]` |
| `RawConstruction.swift` | Initializer inaccessible due to `internal` protection |
| `ImmutableRawValue.swift` | `rawValue` is a `let` constant |
| `NotEncodable.swift` | `ModelID<Restaurant>` does not conform to `Encodable` |
| `NotDecodable.swift` | `ModelID<Restaurant>` does not conform to `Decodable` |
| `ExistingModelExcluded.swift` | `ModelContext` has no member `existingModel` |

`Scripts/check_compilation.py` requires exit 1, the expected number of primary
diagnostics, the fixture path and line, and the model/protocol/access-control
message. Unexpected additional errors fail the check. The absence test is
separate from the three model-association tests: it does not pretend that the
user's `existingModel` example was rejected for a model-type mismatch.

## Native behavior observed

Unless specified otherwise, the following outcomes matched on all three tested
runtimes. They are observations of Apple's default store, not new contracts
provided by TypedSwiftData.

| Experiment | Observed outcome |
| --- | --- |
| Restaurant and Customer before insertion | Identifiers exist; `storeIdentifier == nil` |
| After insertion, before save | Same identifiers; models registered; unsorted identifier fetch includes insertion |
| After `save()` | IDs change for both types; store identifier becomes non-nil; fetch returns current IDs |
| Old temporary copies | Remain equal to their captured values; no longer equal to the model's current ID; cache lookup and predicate fetch miss after save |
| `isTemporary` with runtime 27 | `true` before/after insertion, `false` after save; never invoked on iOS 18.5 |
| Never-inserted ID in a predicate | Zero rows; after insertion, 1 with pending changes and 0 without; after save, old ID returns 0 |
| Generic `persistentModelID` predicate | Saved Restaurant: 1 result; same raw ID queried as Customer: 0 |
| `model(for:)` with never-inserted, deleted, stale-temporary, or foreign-store ID | Returns an instance castable to Restaurant with the requested ID and registers it, despite preceding predicate count 0 |
| Reading `name` on deleted-row placeholder | Fatal error in SwiftData backing-data access; isolated process receives SIGTRAP |
| Pending deletion in owning context | `isDeleted == true`; still registered; normal fetch returns 0; `includePendingChanges = false` returns 1 |
| Saved deletion in owning context | Row fetch returns 0; no registration; retained model's context is nil and `isDeleted` resets to false |
| Two contexts, one container | Unsaved insertion invisible to other context; after save, same ID resolves to a different model instance |
| Deletion from another context | Pending deletion invisible to reader; after save, reader cache can still hold model while predicate returns 0 |
| Registration lifetime | Lookup succeeds while a fetched model is strongly held; after its release, reader lookup returns nil |
| Distinct in-memory containers | IDs and store IDs differ; foreign predicate returns 0 and cache lookup nil, although `model(for:)` still manufactures an instance |
| Two containers, same SQLite file | Unfiltered fetch reads 1 row, old-ID predicate returns 0, IDs compare unequal despite same store identifier |
| SQLite close/reopen | Same anomaly; old-ID concrete and generic predicates return 0, newly fetched ID returns 1 |
| Sorted identifier fetch with pending insertion | Throws exactly `SwiftDataError.sortingPendingChangesWithIdentifiers`; wrapper forwards it |

The SQLite probe verifies the `SQLite format 3` header. Both old context and
container are checked through weak references. Because SwiftData can retain a
container briefly after `save()`, the probe yields for at most 100 × 10 ms, then
the reference harness requires both references to be nil. The XCTest-independent
SQLite test uses `#require` on those same conditions before reopening. Merely
leaving a lexical scope is not treated as closure evidence. Temporary files are
removed after each case.

The SQLite investigation logged equal store identifiers and the same entity/row
URL in native debug descriptions, but unequal native ID values and hashes. A new
ID from the reopened row works; the old one does not. This is a reproducible
identity/lookup anomaly. Its framework-internal cause and intended contract have
not been confirmed by Apple. The package neither parses these descriptions nor
uses serialization to reconstruct an ID.

Actor tests send saved typed IDs between two `@ModelActor` instances, an ordinary
actor holding a `Set<ModelID<Restaurant>>`, and a detached task. They resolve data
inside the receiving model actor, returning only a String, Bool, or IDs. They
cover both in-memory and temporary SQLite containers. No model instance is sent
across actors. This proves compilation and those executed exchanges; it does not
promise freshness after a later concurrent mutation.

## SDK comparison and unavailable checks

The inspected macOS 26.5 SwiftData interface has no `PersistentIdentifier.isTemporary`.
The 27.0 interface declares it with macOS/iOS 27 availability. The library never
uses it. The experimental logger uses `SDK_HAS_TEMPORARY_IDENTIFIER` at compile
time and `#available(macOS 27, iOS 27, *)` at runtime.

The retained API and all positive/negative fixtures compiled against macOS SDKs
26.5 and 27.0, and the iOS 27.1 SDK. The two macOS SDK builds had the same tested
native results on the host runtime. iOS 18.5 and 27.0 had the same logical
outcomes; debug representations and fatal-error source line numbers differed.
No broader SDK or runtime equivalence is claimed.

Not verified in this environment: actual iOS 17 or macOS 14 execution; Xcode 26.6
or Swift compiler 6.0 execution; physical iOS hardware; another macOS runtime;
schema migration; CloudKit; custom stores; multiple configured stores in one
container; concurrent cross-process writes. SQLite reopening was tested within
one process while retaining the raw native ID, not serialization across app
launches. Codable is deliberately outside scope.

## Initial failures and corrections

The first runtime suite had two failing expectations. One assumed a previously
fetched actor-local model would remain registered after the last reference was
released. The corrected test keeps the model alive while asserting registration,
and a native probe records the lifetime behavior. The other attempted to sort
identifiers with pending insertions; SwiftData threw its documented error type.
That error is now asserted for both the native and typed calls, with ordinary
descriptor forwarding tested on saved rows. [Initial log — local evidence](evidence/README.md)

The first negative-fixture run correctly rejected two model mismatches but used
different compiler wording than initially expected (result assignment rather
than argument conversion). Expectations now match those precise type errors;
they were not weakened to exit-code checks.

The first 26.5-SDK client run failed because that standalone SDK could not locate
Apple's macro plugin. Explicitly selecting the installed Xcode plugin fixed the
tool setup. [Initial diagnostics — local evidence](evidence/README.md)

A repeated 26.5-SDK native run found the context released but the container still
briefly alive. That run is retained as a failure, and led to the bounded release
wait described above. Final runs required actual nil weak references.
[Timing observation — local evidence](evidence/README.md)

The initial Xcode test command used the library scheme, which has no test action.
Tests then ran successfully with `TypedSwiftData-Package`. The first manually
linked simulator probe also emitted a sysroot warning; rebuilding through
`xcrun --sdk iphonesimulator` removed it, and `vtool` confirmed IOSSIMULATOR,
minimum OS 17.0, SDK 27.1. The final recorded probe matrix uses that corrected
binary. These setup attempts are not counted as successful validation.

## Reproduction

The common commands are in [README.md](../README.md). For the additional SDK:

```sh
python3 Scripts/check_compilation.py \
  --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
  --label macos26_5 \
  --external-plugin-path '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins#/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server'
```

For runtime tests, choose an available simulator from `xcrun simctl list devices`:

```sh
xcodebuild -scheme TypedSwiftData-Package \
  -destination 'platform=iOS Simulator,id=<SIMULATOR-UDID>' \
  -derivedDataPath .build/xcode-simulator -parallel-testing-enabled NO \
  SWIFT_VERSION=6 SWIFT_STRICT_CONCURRENCY=complete \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES IPHONEOS_DEPLOYMENT_TARGET=17.0 \
  CODE_SIGNING_ALLOWED=NO test

mkdir -p .build/probes
xcrun --sdk iphonesimulator swiftc -parse-as-library -swift-version 6 \
  -strict-concurrency=complete -warnings-as-errors \
  -DSDK_HAS_TEMPORARY_IDENTIFIER -target arm64-apple-ios17.0-simulator \
  Experiments/Models.swift Experiments/SwiftDataExperiments.swift \
  -o .build/probes/native-ios-simulator
codesign --force --sign - .build/probes/native-ios-simulator
python3 Scripts/run_experiments.py --binary .build/probes/native-ios-simulator \
  --simulator '<BOOTED-SIMULATOR-UDID>' --label native-ios --verify-reference
```

The JSON reports include exact command arguments, process status, standard
output, diagnostics, and verification failures. Reference verification includes
known native limitations and should be reviewed when an OS changes, not updated
blindly to obtain green output.

During the final review, scripts were changed to write new reports under
`.build/verification` by default. Use `--report-dir docs/evidence/review` to save
an intentional evidence snapshot. Older reports above were not overwritten.

## Sources and recommendation

Apple's documentation and the installed `.swiftinterface` files informed the
experiments; runtime claims above come from executed probes.

- [PersistentIdentifier](https://developer.apple.com/documentation/swiftdata/persistentidentifier)
- [isTemporary](https://developer.apple.com/documentation/swiftdata/persistentidentifier/istemporary)
- [model(for:)](https://developer.apple.com/documentation/swiftdata/modelcontext/model(for:))
- [ModelContext](https://developer.apple.com/documentation/swiftdata/modelcontext)

**Prepare 0.1.0 with the four retained API elements.** They provide useful static
model association and Sendable identifier transport while preserving native
behavior. Keep `existingModel` excluded, state the container-lifetime limitations,
and verify the oldest supported runtimes before claiming runtime coverage for
the complete deployment range. Nothing had been published at that checkpoint.
