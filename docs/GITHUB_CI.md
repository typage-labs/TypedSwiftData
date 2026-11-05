# GitHub CI validation

Date: 2026-11-05. The repository
[typage-labs/TypedSwiftData](https://github.com/typage-labs/TypedSwiftData) was
created with **PRIVATE** visibility, the requested description, and `main` as
the intended primary branch. No remote README/license was generated.

The initial hosted validation is pending. No hosted compatibility result is
claimed until the workflow jobs have actually executed.

## Audited upload

Production source hashes match the reviewed implementation. `.build`,
`.swiftpm`, DerivedData, Xcode user state, Python caches, raw local evidence,
test result bundles, logs, and local environment files are excluded from Git.
Only the evidence policy and portable summaries are versioned. LICENSE,
README, Package.swift, CHANGELOG, sources, tests, experiments, and scripts remain.

The repository is independent of TypedCoreData. No TypedCoreData file is read
or modified by this task, and no public API is added or changed.

## Workflow requirements

| Job | Requested runner | Required toolchain |
| --- | --- | --- |
| A | `xcode-27` | An installed Xcode 27; exact selected version/build recorded |
| B | `macos-26` | Explicitly selected Xcode 26.6; no fallback to another family |

Both jobs run macOS tests, iOS simulator tests using a verified installed device,
positive and diagnostic-checked negative compilation, the harness regression,
an iOS device build, and isolated native probes. `fail-fast: false` preserves the
other job's result when one fails. Permissions are `contents: read`; there is no
release, package-publishing, or tag step.

The selected Xcode, Swift, macOS and simulator runtime are captured in job
artifacts along with discovered/passed/skipped/failed test counts. A missing
toolchain or simulator fails the job. Native process failures remain fatal to
the harness unless they match the specifically checked deliberate trap.

## Current verdict

**NOT READY** until hosted results are observed and the remaining release
conditions are reviewed. iOS 17/macOS 14 runtimes and Swift compiler 6.0 remain
unverified. A new SDK compiling an old deployment target does not validate
that runtime. No public visibility change, version tag, or release is authorized.
