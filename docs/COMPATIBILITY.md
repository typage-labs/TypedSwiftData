# Compatibility evidence — 2026-11-06

Declared minimums and tested environments are separate. The latest local
[SQLite/runtime validation](SQLITE_RUNTIME_VALIDATION.md) separates memory
lifetime from persistence and records successful real process restarts. The
[initial iOS 17.5 diagnosis](IOS17_RUNTIME_VALIDATION.md) preserves the earlier
failure rather than relabeling it as a pass.

## Current local validation

All rows below use **Xcode 27.1 (27A9275)** / Apple **Swift 6.4**
(`swiftlang-6.4.0.34.1`), Swift 6 mode, complete concurrency and warnings as errors.

| Actual runtime | Runtime tests: passed / skipped / failed | SQLite restart phases | Native memory controls |
| --- | --- | --- | --- |
| iOS **17.5 (21F79)** | **14 / 1 / 0** | **3 / 3 passed**, integrity `ok` | 6 completed; container retention recorded |
| iOS **18.5 (22F77)** | **14 / 1 / 0** | **3 / 3 passed**, integrity `ok` | 6 completed |
| iOS **27.0 (24A434)** | **15 / 0 / 0** | **3 / 3 passed**, integrity `ok` | 6 completed |
| iOS **27.1 (24A94425)** | **15 / 0 / 0** | **3 / 3 passed**, integrity `ok` | 6 completed |
| macOS **27.0.1 (26A434)** | **15 / 0 / 0** | **3 / 3 passed**, integrity `ok` | 6 completed |

The one skip on iOS 17.5/18.5 is the existing inheritance test requiring iOS 26.
The other tests actually execute, including SQLite and actor transmission.
Three separate processes save data, read/delete it, and verify persisted deletion;
this is additional coverage, not a renaming of two simultaneous containers.

The earlier iOS 17.5 result was 13 passed / 1 failed / 1 skipped after fixing the
model-construction fixture. The remaining assertion required native container
deallocation within about one second. Native-only controls reproduced retention
with no caller-owned model, context or ID, and persistence after process exit
passed. The test now checks functional behavior across containers; the memory
diagnostic and true-restart check are separate. No timeout increase or broad
skip was used to turn that failure into success.

## Final hosted coverage

The [GitHub CI report](GITHUB_CI.md) records both successful jobs on the revised
tests, exact run links and artifacts. The three-process SQLite checks and six
native lifetime diagnostics ran on macOS and iOS in **both** hosted jobs. Xcode
26.6 was exercised on GitHub, not installed locally.

| Hosted runner | Xcode / Swift | macOS runtime | iOS simulator | Runtime results |
| --- | --- | --- | --- | --- |
| `xcode-27` | 27.2 (27B52) / 6.4.2 (`swiftlang-6.4.2.1.9`) | 27.0.1 (26A434) | 27.2 (24B8117) | 15 macOS + 15 iOS passed; no skips/failures; 3 restart phases passed per runtime |
| `macos-26` | 26.6 (17F113) / 6.3.3 (`swiftlang-6.3.3.1.3`) | 26.6.2 (25G83) | 26.5 (23F77) | 15 macOS + 15 iOS passed; no skips/failures; 3 restart phases passed per runtime |

## Limits of each kind of evidence

| Dimension | Actual coverage | What it does not prove |
| --- | --- | --- |
| Swift language | Swift 6 mode, complete concurrency, warnings as errors | Execution with the Swift 6.0 compiler |
| Compiler/toolchain | Revised tests: local 27.1; hosted 26.6 and 27.2 | Every intermediate toolchain |
| macOS SDKs | 27.0 locally; earlier 26.5/27.2 hosted; arm64 target macOS 14.0 | macOS 14 runtime; Intel execution |
| iOS SDK/device builds | 27.1 locally; earlier 26.5/27.2 hosted; arm64 target iOS 17.0 | iOS 17.0 runtime or physical device execution |
| Compiler fixtures | Local and both hosted jobs: 3 positive + 10 diagnostic-checked negative per macOS/iOS SDK | Any nonzero compiler exit being acceptable |
| Runtime suite | Memory, SQLite, actors, generic use; inheritance only where available | Every patch release or application schema |
| Process restart | Exact saved values and deletions verified after process exit on all current rows | Portable ModelID values, UIKit lifecycle, migrations, abrupt-crash/power-loss durability |
| Memory lifecycle | Six native-only controls per runtime; retention after construction/save on 17.5; unsaved insertion retained on all rows | A guaranteed release deadline, or proof of a permanent leak |
| Harness checks | 4 Python regressions; real reader rejects absent saved data; complete local verification entry point passed | Arbitrary native failures being safe to ignore |
| Original native experiments | 15 macOS probes passed their process checks, including one specific deliberate trap | Correctness of all native SwiftData lookups |
| Historical standalone SDK comparison | SDK 26.5 fixtures with Xcode 27.1's macro plugin passed before hosted validation | An independent older toolchain by themselves |

`swift-tools-version: 6.0` and `swiftLanguageModes: [.v6]` describe tools/language
requirements, not execution with the Swift 6.0 compiler. The package's iOS 17 /
macOS 14 declarations are deployment targets. Only the exact runtimes above
have execution evidence.

Production code does not use `PersistentIdentifier.isTemporary`. Its optional
experimental use remains guarded by both a compile flag and iOS/macOS 27
availability; none of the new restart/lifetime probes uses it.

**iOS 17.5 is validated for the exercised current API scenarios.** iOS 17.0,
other untested patch versions, macOS 14, physical iOS hardware and Intel remain
unverified. Native identifier equality/resolution across containers or launches
is still not guaranteed. `existingModel`, Codable and public raw constructors
remain excluded. These coverage gaps and semantic limits remain explicit in
the release documentation. Technical readiness does not validate unexecuted
runtimes, and publication still requires the maintainer's separate approval.
