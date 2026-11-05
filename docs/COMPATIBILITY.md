# Compatibility evidence — 2026-11-05

Declared minimums and tested environments are separate. This matrix describes
executed checks, not a promise that every intervening version behaves the same.
See [release review](RELEASE_REVIEW.md) for counts and evidence.

| Dimension | Actual coverage | What it does not prove |
| --- | --- | --- |
| Swift language | Swift 6 mode; complete concurrency checks; compiler warnings treated as errors | Execution with the Swift 6.0 compiler |
| Compiler | Apple Swift 6.4, `swiftlang-6.4.0.34.1` | Older Swift compiler compatibility |
| Xcode | Xcode 27.1, build 27A9275 | Xcode 26.6 execution; 26.6 remains an intended floor |
| macOS SDK | SDK 27.0, plus standalone SDK 26.5 | macOS 26.5 runtime behavior |
| macOS compilation | arm64 targeting macOS 14.0 | Running on macOS 14; Intel execution |
| macOS runtime | macOS 27.0.1, build 26A434; 15 runtime tests | macOS 14 runtime coverage |
| iOS SDK / device build | SDK 27.1, `arm64-apple-ios17.0`; build succeeded | Physical device execution or iOS 17 runtime behavior |
| iOS simulator runtime | iOS 27.0 (24A434): 15 tests; iOS 18.5 (22F77): 14 executed + 1 inheritance test skipped | iOS 17 runtime coverage |
| Model inheritance | Compiles with availability guards; executed on macOS/iOS 27 | Inheritance on iOS 17/18 or macOS 14; no such claim is made |
| Standalone SDK comparison | Positive/negative fixtures passed on macOS SDK 26.5 using Xcode 27.1's Apple macro plugin | An independent older Xcode/macro/compiler combination |
| CI | Local execution of the prepared CI script from a clean local Git checkout | A hosted GitHub Actions run |

`swift-tools-version: 6.0` declares the manifest tools version;
`swiftLanguageModes: [.v6]` declares the language mode. Neither is a record of
running the Swift 6.0 toolchain. The package's `.iOS(.v17)` / `.macOS(.v14)`
platform declarations are deployment targets, not test results.

The installed SDK exposes `PersistentIdentifier.isTemporary` only starting with
iOS/macOS 27. Production code does not reference it. Experimental use has a
compile flag and a runtime availability check; the iOS 18.5 run does not call it.

Available older iOS 18 runtimes do not replace the missing iOS 17 runtime. No
runtime download, Xcode installation, SDK modification, or unsupported backport
was performed for this review.

The publication checklist requires minimum-runtime coverage or an explicit,
human-approved revision to the support policy before publishing 0.1.0.
