# GitHub CI validation — 2026-11-05

The [private repository](https://github.com/typage-labs/TypedSwiftData) uses `main`
and the description “Strongly typed model identifiers for Apple's SwiftData
framework.” No remote README/license was generated; no tag or release was
created. The four public API elements are unchanged from the local review.

## Observed hosted execution

[Run 42111357262](https://github.com/typage-labs/TypedSwiftData/actions/runs/42111357262)
passed both jobs on commit
[`770643d6de6fe11a238d5439af18607ae03bc1b1`](https://github.com/typage-labs/TypedSwiftData/commit/770643d6de6fe11a238d5439af18607ae03bc1b1).
Neither job required a retry, an expectation change, or a production-code fix.
The later documentation commit records these results; its own status is visible
in the [workflow history](https://github.com/typage-labs/TypedSwiftData/actions/workflows/verify.yml).

| Observed property | Job A | Job B |
| --- | --- | --- |
| Job | [Xcode 27](https://github.com/typage-labs/TypedSwiftData/actions/runs/42111357262/job/127539454288) | [Xcode 26.6](https://github.com/typage-labs/TypedSwiftData/actions/runs/42111357262/job/127539454787) |
| Requested runner | `xcode-27` | `macos-26` |
| Actual image / revision | `xcode-27-arm64` / `20261026.0314.1` | `macos-26-arm64` / `20261102.0473.1` |
| Selected Xcode | **27.2 RC**, build **27B48** | **26.6**, build **17F113** |
| Apple Swift | **6.4.2**, `swiftlang-6.4.2.1.9`, driver `1.168.6` | **6.3.3**, `swiftlang-6.3.3.1.3`, driver `1.148.6` |
| macOS runtime | **27.0.1**, build **26A434** | **26.7.2**, build **25G332** |
| macOS / iOS SDKs | **27.2 / 27.2** | **26.5 / 26.5** |
| Selected simulator | iPhone Duo, **iOS 27.1 (24A94425)** | iPhone 17e, **iOS 26.5 (23F77)** |
| macOS tests: passed / skipped / failed | **15 / 0 / 0** | **15 / 0 / 0** |
| iOS tests: passed / skipped / failed | **15 / 0 / 0** | **15 / 0 / 0** |
| Positive compilation, per SDK | **3 / 3** | **3 / 3** |
| Negative compilation, per SDK | **10 / 10**, expected diagnostics verified | **10 / 10**, expected diagnostics verified |
| Harness regression | **1 passed** | **1 passed** |
| Isolated macOS native probes | **15 checked, 0 unexpected failures** | **15 checked, 0 unexpected failures** |
| Generic iOS device build | Passed, deployment target iOS 17 | Passed, deployment target iOS 17 |

Counts come from Swift Testing's final summaries, not the separate XCTest line
reporting zero tests. Each runtime execution discovers 15 tests in three suites,
covering memory, SQLite, actors, generic use and inheritance. Inheritance is
available on both hosted runtime pairs, so no runtime test was skipped here.
The earlier local iOS 18.5 execution explicitly skipped one inheritance test.

Each SDK compilation batch also emits the library module: 14 compiler
invocations for 3 positive and 10 negative client fixtures. Both SDK batches
use Swift 6, complete concurrency checking and warnings as errors, targeting
`arm64-apple-macosx14.0` and `arm64-apple-ios17.0`. Rejections check the primary
error's count, file, line and message pattern. They cover model mismatches,
invariance, inaccessible construction, immutability, absent Codable/existence
APIs, and direct existential access. None passed merely because compilation
returned a nonzero exit code.

## Comparison with local validation

The local pre-push run used Xcode 27.1 (27A9275), Apple Swift 6.4
(`swiftlang-6.4.0.34.1`), macOS 27.0.1 and iOS 27.0 (24A434). It passed the same
15 macOS tests, 15 iOS tests, compiler fixtures and harness regression. Hosted
CI adds a complete Xcode 26.6 toolchain/runtime combination and Xcode 27.2 RC;
the earlier standalone SDK 26.5 check was not a substitute for that combination.

The ten primary rejection messages match the local run on both hosted
toolchains. No diagnostic exception or test availability workaround was added.
Xcode's App Intents metadata extraction warning appears in both iOS build logs;
it is unrelated to a test skip and did not suppress any Swift Testing execution.

Native probes run in observation mode. The harness enforces process completion
and the one specific deliberate trap; it does not assert all native snapshot
fields in this mode. Inspection of the recorded fields found the same lifecycle,
pending-deletion, registration and SQLite behavior as the local reference:

- Saving a new model replaces its temporary ID; previously copied IDs stay old.
- Registration can include pending-deleted or stale instances and disappear
  when an unretained instance leaves the native registration cache.
- Two contexts sharing one container can resolve a saved ID. Different
  containers provide no general resolution guarantee.
- In the same-file/two-container and SQLite-reopen probes, the row still exists
  but the old ID predicate finds zero rows, while the newly obtained ID finds it.
- Native `model(for:)` can return a castable placeholder. Reading the deleted
  placeholder's property produces the expected **SIGTRAP (-5)** and checked
  invalidated-backing-data diagnostic, in an isolated child process.
- Sorted identifier fetches with pending insertions throw the recorded native
  error. The wrapper preserves that error.

For each job, 14 probes finish with exit 0 and one has the precisely expected
trap. An unrelated crash, missing completion marker or launcher failure fails
the job. Matching these observations does not certify SwiftData correctness or
justify adding an existence resolver.

## Workflow and evidence audit

The jobs explicitly select an installed Xcode from the requested family and
record the exact version/build. Job A chose the highest installed Xcode 27,
which was a release candidate; it is not described as a stable Xcode 27.2
release. Each job verifies simulator availability using `simctl` before using
its UUID. No simulator destination is hardcoded. `fail-fast: false` lets both
jobs report results. Permissions are `contents: read`, with checkout credentials
not persisted. There is no publishing, release or tag step.

The private run includes `verification-xcode-27` and `verification-xcode-26.6`
artifacts: summaries, actual versions, simulator inventory, compilation
diagnostics, runtime logs, probe results, harness output and command exit codes.
An incomplete test summary cannot be recorded as success. Raw artifact files
are not copied into Git; [the evidence policy](evidence/README.md) explains the
portable summaries and local reports.

Before pushing, `.gitignore` and the staged inventory were audited. `.build`,
`.swiftpm`, DerivedData, Xcode user state, Python caches, raw local evidence,
test result bundles, logs and local environment files are excluded. Required
package files, Apache 2.0 LICENSE, documentation, sources and tests are present.
Production source hashes matched the reviewed implementation. TypedCoreData
was not modified.

## Release assessment

**Private GitHub CI validation: complete and green.** Xcode 26.6 is now an
executed compatibility result, rather than an intended floor alone.

**NOT READY for public release under the existing release checklist:** iOS 17
and macOS 14 runtime coverage is still missing. Neither hosted image supplied
iOS 17, and neither host ran macOS 14. The maintainer must either obtain that
coverage or explicitly accept/revise the support policy before publication.
Compilation for those deployment targets is not runtime validation.

Swift compiler 6.0, physical iOS hardware and Intel execution remain unverified;
the package only claims Swift 6 language mode and the environments listed here.
The new CI runs exercise native subprocess probes on macOS; iOS CI exercises
the package runtime suites, not that entire native probe program. Historical
iOS probe observations remain documented separately. Public visibility, a
version tag and a release still require a separate publication instruction.
