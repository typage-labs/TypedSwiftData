# iOS 17 runtime diagnosis — 2026-11-06

**Historical initial diagnosis.** The failures below were real and are retained
as evidence. The later [SQLite/runtime investigation](SQLITE_RUNTIME_VALIDATION.md)
replaced the invalid release-deadline oracle with separate memory and real
process-restart checks. That subsequent run passed 14 tests with 1 availability
skip on iOS 17.5. The statements below describe the earlier state, not the
current compatibility verdict.

**The simulator works and the complete test suite was launched on iOS 17.5.
The final run is FAILED: 13 passed, 1 failed, 1 explicitly skipped.** This is
partial runtime evidence, not confirmation that the whole suite passes on iOS
17.5, nor a validation of iOS 17.0 or all iOS 17 releases.

## Environment and boot

- Xcode **27.1**, build **27A9275**, selected at
  `/Applications/Xcode.app/Contents/Developer` by both `xcode-select` and the
  explicit `DEVELOPER_DIR` used for testing. No global selection was changed.
- Apple Swift **6.4**, `swiftlang-6.4.0.34.1`, clang `2100.3.34.1`,
  swift-driver `1.168.6`; Swift 6 mode with complete concurrency checks and
  warnings treated as errors.
- Host: macOS **27.0.1 (26A434)**, Apple silicon.
- Runtime: **iOS 17.5 (21F79)**, identifier
  `com.apple.CoreSimulator.SimRuntime.iOS-17-5`, reported `isAvailable: true`.
  It was already installed by the maintainer.
- Device: existing **iPhone 15 Pro**, UDID
  `5A22FAA7-10CA-4A24-828D-1F4F81A3B79E`. It was initially shut down.
  `simctl boot` and `simctl bootstatus -b` succeeded, with initial data migration
  finishing in **14 seconds**, independently of TypedSwiftData.
- The device remains **Booted**. The maintainer's already booted iPhone 15 and
  all other devices were preserved. No device creation, erasure, global reset,
  runtime installation/removal or Xcode installation was necessary.
- `xcodebuild -list` identified `TypedSwiftData-Package` as the package scheme;
  `-showdestinations` included this exact iOS 17.5 device. The resulting
  `.xcresult` independently records the UDID, arm64, OS 17.5 and build 21F79.
  Compilation used iPhoneSimulator SDK 27.1, targeting iOS 17.0; execution used
  the explicitly selected **17.5 runtime**, not SDK 27.1's runtime.

## What had failed

The latest pre-existing Xcode result, timestamped 2026-11-06 12:40:20 +0100,
shows that tests had actually executed on the maintainer's iPhone 15 / iOS 17.5:
**13 passed, 1 failed, 1 skipped**. Its failure is
`SQLiteTests.sqliteSaveDeleteAndReopen()` at `releasedContainer == nil`.
There is no download, installation or boot failure in that recorded attempt.
This does not establish what happened in any earlier unrecorded attempt.

Re-running the unmodified suite from the CLI exposed an additional test setup
problem: `equalityHashingAndRawValue()` constructs an uninserted `@Model` before
creating any container for its schema. On iOS 17.5 this traps inside native
SwiftData with `failed to find a currently active container for Restaurant`.
Other test scheduling can initialize the schema first and could explain why
the pre-existing Xcode run did not show this extra failure; its summary alone
does not establish the scheduling order. The CLI result captured
**12 passed, 2 failed, 1 skipped**, including the crash and the SQLite assertion.

After that crash, `xcodebuild` spent over four minutes collecting simulator
diagnostics. A process sample showed
`XCTHRunDestinationAllocator.collectSimulatorDiagnostics` waiting inside
`simCtlDiagnose`; its child command specified `--timeout=600`. Only that
agent-launched diagnostic child was interrupted, after test execution finished.
The result bundle finalized and the command exited **65**, preserving both
failures. This was diagnostic collection after execution, not a simulator boot
failure. The final run uses `-collect-test-diagnostics never` to avoid that
collection delay; test logging, assertions, the result bundle and exit status
remain enabled.

## Minimal correction and native investigation

Only `ModelIDTests.equalityHashingAndRawValue()` was changed: it now creates a
container for the schema and keeps it alive while constructing uninserted
models. Its existing assertions are unchanged. It passes on iOS 17.5, and a
focused macOS regression run also passed **1 test, 0 failures**. No production
source, public API, package configuration, workflow or verification script was
changed.

Separate disposable executables using **Foundation and SwiftData only**, with
no TypedSwiftData import, established:

| Native control on iOS 17.5 | Observed result |
| --- | --- |
| Construct the model before any container | SIGTRAP; native active-container diagnostic, before reading the ID |
| Create and release a container without creating a model/context | Container weak reference nil at the first observation |
| Create model/context, insert and save, retain no ID | Context nil by 1 second; container still non-nil through 10 seconds |
| Same operation while retaining a raw `PersistentIdentifier` | Same retention observations through 10 seconds |
| Disable the container's main-context autosave as well | Container still non-nil through 10 seconds |

These controls reproduce retention without the typed wrapper. They do **not**
identify the precise internal retaining reference or prove a permanent leak.
Ten seconds is the measured observation window. The test's roughly one-second
release deadline is therefore not satisfied on this runtime; simply extending
it to ten seconds did not establish release either.

The native diagnostics needed temporary app-bundle metadata: an unbundled CLI
probe on iOS 17.5 otherwise traps with `Unable to determine Bundle Name`.
Wrapping the executable in a temporary `.app` resolved that diagnostic setup
issue. The real XCTest bundle already has this metadata. Probe SQLite files
were removed only after each probe process exited.

The existing SQLite tests also log native warnings when their `defer` removes
files while SwiftData still retains a store (`vnode unlinked while in use`).
These are unique temporary test databases, not user databases. The test and its
failing release assertion have been preserved; neither a broad skip nor an
expected-failure annotation was added to make the suite green.

## Final complete-suite result

All 15 tests were selected, without `only-testing` or `skip-testing` filters.
Fourteen executed and one was skipped by its existing availability declaration.
`xcodebuild test` exited **65**. Swift Testing and `.xcresult` agree on
**13 passed / 1 failed / 1 skipped**; the separate XCTest “0 tests” line is not
the Swift Testing count.

| Test | Result |
| --- | --- |
| `ModelIDTests/equalityHashingAndRawValue()` | Passed |
| `ModelIDTests/identifiersAreSnapshotsAcrossSave()` | Passed |
| `ModelIDTests/registeredLookupDelegatesAtEveryLifecycleStage()` | Passed |
| `ModelIDTests/fetchPreservesDescriptor()` | Passed |
| `ModelIDTests/pendingSortingErrorsAreForwarded()` | Passed |
| `ModelIDTests/pendingInsertionAndDeletionAreNative()` | Passed |
| `ModelIDTests/twoContextsShareSavedIdentityButNotInstances()` | Passed |
| `ModelIDTests/unrelatedContainersDoNotResolveEachOthersIDs()` | Passed |
| `ModelIDTests/nativeModelForCanManufactureDeletedModel()` | Passed |
| `ModelIDTests/identifiersCrossModelActorsAndOrdinaryActors()` | Passed |
| `ModelIDTests/emptyFetch()` | Passed |
| `SQLiteTests/sqliteSaveDeleteAndReopen()` | Failed |
| `SQLiteTests/identifiersCrossActorsWithSQLite()` | Passed |
| `TypeShapeTests/protocolConstraintsAndOpenedExistential()` | Passed |
| `TypeShapeTests/inheritancePreservesStaticTypeAndNativePolymorphism()` | Skipped |

The skipped inheritance test requires **iOS 26**. The remaining failure is
`SQLiteTests.swift:29`: `#require(releasedContainer == nil)`. Consequently, the
rest of that test — including the assertions after verified closure/reopening
and subsequent deletion — is **not executed**. SQLite identifier transmission
between two model actors does pass; that is not proof of container closure.

## Reproduction and local evidence

From the package root, with a fresh result-bundle output path:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -scheme TypedSwiftData-Package \
  -destination 'platform=iOS Simulator,id=5A22FAA7-10CA-4A24-828D-1F4F81A3B79E' \
  -destination-timeout 60 \
  -derivedDataPath .build/ios17-validation/DerivedData \
  -resultBundlePath .build/ios17-validation/next-suite.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  SWIFT_VERSION=6 SWIFT_STRICT_CONCURRENCY=complete \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES IPHONEOS_DEPLOYMENT_TARGET=17.0 \
  CODE_SIGNING_ALLOWED=NO test
```

Local, Git-ignored evidence is in `.build/ios17-validation/`: `bootstatus.log`,
`environment.json`, `prior-xcode-summary.json`, `original-suite.xcresult`,
`original-summary.json`, `corrected-suite.xcresult`, `corrected-suite.log`,
`corrected-summary.json`, `corrected-tests.json`, the native probe source and
`bundled-*.json` results, `xcodebuild-after-crash.sample.txt`, and
`macos-fixture-regression.log`. The original pre-existing Xcode bundle was only
read. Raw logs and personal machine paths are not added to versioned docs.

## Compatibility conclusion

**iOS 17.5 execution is confirmed; complete runtime compatibility is not yet
validated.** No defect in the four public wrappers has been demonstrated by
these failures. The fixture initialization defect is corrected; the SQLite
closure precondition still fails because of the observed native retention.
A future closure/reopening validation should use separate writer/reader
processes with verified writer termination and safe post-exit cleanup, instead
of assuming an in-process container is released within a deadline. That work
was not substituted for the failing test in this run.

iOS 17.0, other iOS 17 patch versions, physical devices and macOS 14 remain
unverified. No commit, push, tag, release or visibility change was performed.
