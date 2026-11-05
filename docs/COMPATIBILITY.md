# Compatibility evidence — 2026-11-05

Declared minimums and tested environments are separate. This matrix describes
executed checks, not a promise that every intervening version behaves the same.
The [GitHub CI report](GITHUB_CI.md) records exact builds, counts and run links;
the [local release review](RELEASE_REVIEW.md) preserves earlier observations.

| Environment | Xcode / Swift compiler | macOS runtime | iOS simulator runtime | Runtime results (macOS; iOS) |
| --- | --- | --- | --- | --- |
| GitHub `xcode-27` | 27.2 RC (27B48) / 6.4.2 (`swiftlang-6.4.2.1.9`) | 27.0.1 (26A434) | 27.1 (24A94425) | 15 passed; 15 passed; no skips/failures |
| GitHub `macos-26` | 26.6 (17F113) / 6.3.3 (`swiftlang-6.3.3.1.3`) | 26.7.2 (25G332) | 26.5 (23F77) | 15 passed; 15 passed; no skips/failures |
| Local review | 27.1 (27A9275) / 6.4 (`swiftlang-6.4.0.34.1`) | 27.0.1 (26A434) | 27.0 (24A434) | 15 passed; 15 passed; no skips/failures |
| Local older simulator | 27.1 (27A9275) / 6.4 | Same local host | 18.5 (22F77) | iOS: 14 passed, 1 explicit inheritance skip, 0 failed |

| Dimension | Actual coverage | What it does not prove |
| --- | --- | --- |
| Swift language | Swift 6 mode; complete concurrency checks; compiler warnings treated as errors | Execution with the Swift 6.0 compiler |
| Xcode | Complete hosted runs on 26.6 and 27.2 RC; local 27.1 | Every intermediate toolchain version |
| macOS SDKs | 26.5 with Xcode 26.6; 27.0 locally; 27.2 with Xcode 27.2 RC | Runtime behavior of the deployment minimum |
| macOS compilation | arm64 targeting macOS 14.0; positive and diagnostic-checked negative fixtures | Running on macOS 14; Intel execution |
| iOS SDKs / device builds | 26.5, 27.1, 27.2; `arm64-apple-ios17.0`; actual generic device builds succeeded | Physical device execution or iOS 17 runtime behavior |
| Runtime suites | Memory, SQLite, actor and type-shape tests on the environments above | iOS 17 / macOS 14 runtime coverage |
| Model inheritance | Availability guards; executed on hosted macOS 26/27 and iOS 26/27; explicit skip on iOS 18.5 | Inheritance on systems before iOS/macOS 26 |
| Native probes | 15 isolated macOS probes per hosted job; no unexpected failures; one checked deliberate trap each | Correctness of all SwiftData lookups; hosted iOS execution of the complete probe program |
| Compiler diagnostics | 3 positive and 10 negative fixtures per SDK on both hosted toolchains; same primary error messages as local | Any compilation error being an acceptable rejection |
| Harness regression | One regression test passed per job, checking that failed probes fail observation mode | Arbitrary native failures being safe to ignore |
| Historical standalone SDK comparison | SDK 26.5 fixtures with Xcode 27.1's macro plugin also passed | An independent older toolchain; that gap is now covered separately by hosted Xcode 26.6 |

`swift-tools-version: 6.0` declares the manifest tools version;
`swiftLanguageModes: [.v6]` declares the language mode. Neither is a record of
running the Swift 6.0 toolchain. The package's `.iOS(.v17)` / `.macOS(.v14)`
platform declarations are deployment targets, not test results.

`PersistentIdentifier.isTemporary` is available starting with iOS/macOS 27 in
the inspected SDK. Production code does not reference it. Optional experimental
use has a compile flag and runtime availability check; neither CI job enables
that optional logger. This does not skip a runtime test or claim older-system
availability of that API.

No iOS 17 runtime or macOS 14 host was available in these executions. No runtime
download, Xcode installation, SDK modification or unsupported backport was
performed. The publication checklist still requires minimum-runtime coverage
or explicit maintainer acceptance of a revised support policy before 0.1.0.
