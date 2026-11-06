# Final GitHub CI validation — 2026-11-06

**Both hosted jobs passed the revised tests and SQLite process checks.** The
[repository](https://github.com/typage-labs/TypedSwiftData) remains **private**,
with `main` as its default branch. No tag, GitHub Release or publication was
created. The four public API elements and package manifest are unchanged from
`7672530a2be0116a4d378d4dd0e83e8a6a70e154`.

## Audited code and observed execution

The integration commit is
[`dab3240b2401399d35badead408fceb9aa5557fb`](https://github.com/typage-labs/TypedSwiftData/commit/dab3240b2401399d35badead408fceb9aa5557fb).
[Run 42239504551](https://github.com/typage-labs/TypedSwiftData/actions/runs/42239504551)
passed both jobs on its first attempt. No follow-up code/test adjustment or
rerun was needed to obtain those CI results.

The tables below record that code-validation run. The documentation follow-up
records these observations and is also subject to the complete workflow; its
own run is available in the
[workflow history on main](https://github.com/typage-labs/TypedSwiftData/actions/workflows/verify.yml).
The final handoff verifies that the latest pushed commit's own two jobs are
green, rather than relying on the parent commit's result.

| Observed property | Job A | Job B |
| --- | --- | --- |
| Job link | [Xcode 27](https://github.com/typage-labs/TypedSwiftData/actions/runs/42239504551/job/127965749892) | [Xcode 26.6](https://github.com/typage-labs/TypedSwiftData/actions/runs/42239504551/job/127965750186) |
| Requested runner | `xcode-27` | `macos-26` |
| Image / revision | `xcode-27-arm64` / `20261104.0337.1` | `macos-26-arm64` / `20261026.0455.2` |
| Selected Xcode | **27.2 (27B52)** | **26.6 (17F113)** |
| Apple Swift | **6.4.2**, `swiftlang-6.4.2.1.9`, driver `1.168.6` | **6.3.3**, `swiftlang-6.3.3.1.3`, driver `1.148.6` |
| macOS runtime | **27.0.1 (26A434)** | **26.6.2 (25G83)** |
| macOS / iOS SDK | **27.2 / 27.2** | **26.5 / 26.5** |
| Selected simulator | iPhone 17e, **iOS 27.2 (24B8117)** | iPhone 17 Pro, **iOS 26.5 (23F77)** |
| macOS tests: executed / passed / skipped / failed | **15 / 15 / 0 / 0** | **15 / 15 / 0 / 0** |
| iOS tests: executed / passed / skipped / failed | **15 / 15 / 0 / 0** | **15 / 15 / 0 / 0** |
| Python harness tests: executed / passed / failed | **4 / 4 / 0** | **4 / 4 / 0** |
| Positive compilation fixtures, per SDK | **3 / 3 verified** | **3 / 3 verified** |
| Negative compilation fixtures, per SDK | **10 / 10 expected rejections verified** | **10 / 10 expected rejections verified** |
| Actual generic iOS device build | Passed, deployment target 17.0 | Passed, deployment target 17.0 |
| Native macOS experiments | **15 process checks passed** | **15 process checks passed** |

The runtime counts come from Swift Testing, not the separate XCTest summary
that reports zero tests for these suites. Inheritance is available on these
hosted runtimes, so no runtime test was skipped. The native experiment count
contains 14 normal completions and one specifically checked deliberate
**SIGTRAP (-5)** in an isolated process, not an unexpected failure.

Both toolchains verified the same ten primary compiler rejection messages as
the local run. The checks still require the expected error count, file, line
and message. Each SDK batch additionally compiles the library module, for
14 compiler invocations per SDK; negative exits are expected rejections, not
unexplained build failures.

## SQLite checks actually executed in CI

Both jobs run `check_sqlite_restart.py --lifetime` on **macOS and the selected
iOS simulator**, unconditionally after the corresponding prerequisites.

| Job / runtime | Writer / reader-deleter / final reader PIDs | Phases passed | Integrity | Lifetime controls |
| --- | --- | --- | --- | --- |
| Xcode 27 / macOS | 5669 / 5670 / 5671 | **3 / 3** | `ok` | **6 completed** |
| Xcode 27 / iOS | 9404 / 9416 / 9426 | **3 / 3** | `ok` | **6 completed** |
| Xcode 26.6 / macOS | 1664 / 1670 / 1676 | **3 / 3** | `ok` | **6 completed** |
| Xcode 26.6 / iOS | 6045 / 6049 / 6199 | **3 / 3** | `ok` | **6 completed** |

For each row, the artifacts confirm normal zero exits, distinct process IDs,
the same unique stored nonce, Restaurant row counts **1 → 0 → 0**, and one
unchanged Customer sentinel. The reader checks the saved value, obtains fresh
typed IDs, compares native/typed behavior, verifies registration and saves the
deletion. The final process confirms persisted deletion and the surviving
sentinel. The parent checks the actual SQLite header and `integrity_check`.
No old `ModelID` or `PersistentIdentifier` is serialized or reconstructed.

The memory controls are a separate native-only diagnostic. Retention is
recorded as an observation, not converted into a persistence failure or a
promise about deallocation. Unexpected child failure, timeout, missing
completion, incorrect nonce/count or integrity failure still fails the job.
The Python regressions verify important failure paths, and the earlier local
real-reader negative control rejected missing persisted data.

## Local evidence and remaining limits

The pre-push local complete verification passed on **Xcode 27.1 (27A9275)**,
Swift **6.4** (`swiftlang-6.4.0.34.1`), macOS **27.0.1 (26A434)** and iOS
**17.5 (21F79)**: 15 macOS tests passed; 14 iOS tests passed and the inheritance
test was explicitly skipped because it requires iOS 26. Both local process
restart batches, four Python regressions and compiler fixture batches passed.
Additional earlier local executions of the same revised runtime tests covered
iOS 18.5, 27.0 and 27.1. See [the runtime report](SQLITE_RUNTIME_VALIDATION.md)
and [compatibility matrix](COMPATIBILITY.md).

**iOS 17.5 is runtime-validated for the exercised API scenarios. iOS 17.0 and
macOS 14 were not executed.** Other untested versions, physical devices, Intel
execution and the Swift 6.0 compiler remain uncovered. A deployment-target
build does not establish runtime execution on that minimum version.

SQLite data persistence and saved deletion survive the tested normal process
restarts. Identifier stability, existence, permanence and store membership
remain unpromised. Native `ModelContainer` retention was observed on iOS 17.5,
including without caller-owned models, contexts or IDs; the internal retaining
reference and permanent leakage have not been established. No guarantee about
UIKit lifecycle, migrations, sudden crashes or power-loss durability is added.

## Audit and repository state

The diff from `7672530a` contains test fixture corrections, the separate runtime
probes, verification/reporting scripts, documentation and the workflow step
label. Production source hashes and `Package.swift` match the baseline. The
new process probe imports the real library as an external client; the memory
probe does not link it. TypedCoreData was not modified.

`.gitignore` and the candidate/staged inventories were checked: `.build`,
DerivedData, temporary SQLite stores, binaries, logs, `.xcresult`, personal
configuration and raw local evidence are excluded. Required package files and
the existing Apache 2.0 license remain present. The workflow retains
`contents: read`, non-persisted checkout credentials and artifact upload with
`if: always()`. It verifies Xcode versions and installed simulators; there is
no hardcoded simulator model or publishing step.

The private artifacts `verification-xcode-27` and `verification-xcode-26.6`
contain version records, test counts/logs, compiler diagnostics, step exits,
SQLite phase evidence and native observations. The earlier pre-SQLite hosted
validation is preserved in
[run 42113100885](https://github.com/typage-labs/TypedSwiftData/actions/runs/42113100885).

## Technical readiness

**READY FOR PUBLIC RELEASE**, subject to the maintainer's separate publication
decision. No demonstrated API defect, unexplained test failure, missing required
CI check or artifact leak remains in this review. The explicit coverage limits
above remain part of the release documentation; readiness is not a claim that
unexecuted runtimes have been validated. No public visibility change, tag or
GitHub Release is performed by this task.
