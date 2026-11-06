# 0.1.0 — release process and evidence

The maintainer authorized official publication on **2026-11-06**, including
public repository visibility, tag `0.1.0` and the GitHub Release, conditional on
both CI jobs passing the distinct release-documentation commit and a clean
final audit. The tag must point to that newly validated commit, not the earlier
`902151e` reference. Sources, tests and all four public API elements remain unchanged.

Historical technical readiness evidence is in the [CI report](GITHUB_CI.md).
Publication information and exact-version installation instructions are in the
[README](../README.md); the canonical outcome is the
[0.1.0 release](https://github.com/typage-labs/TypedSwiftData/releases/tag/0.1.0).

## Technical checks

- [x] Four public API elements unchanged from the reviewed implementation.
- [x] Internal constructor, immutable raw value, no Codable or public raw factory.
- [x] Native semantics preserved; no existence, permanence or store guarantee.
- [x] iOS 17.5 model-construction fixture corrected without changing production code.
- [x] Memory lifetime separated from SQLite persistence; native retention recorded.
- [x] Real writer, reader/deleter and final reader processes verify stored data,
  deletion and an unrelated data sentinel. Process failures remain fatal.
- [x] Local complete verification passed, including iOS 17.5 runtime execution,
  explicit inheritance availability skip, macOS tests and compiler diagnostics.
- [x] Revised tests and process checks passed both hosted Xcode jobs; inspect
  artifacts and record actual versions/counts on the pushed code.
- [x] Required package files and canonical Apache 2.0 license present; no external
  dependency, imported third-party implementation or custom Swift macro added.
- [x] Generated stores, binaries, raw logs, result bundles and personal files
  excluded from Git. Production source hashes unchanged.
- [x] Prepublication validation used the private repository and branch `main`,
  normal push only; workflow permissions
  `contents: read`, no publishing or release step.

## Coverage limits to retain in the release documentation

The manifest declares deployment targets iOS 17/macOS 14. The compatibility
matrix names only actually executed runtimes: iOS 17.5 is verified; **iOS 17.0
and macOS 14 are not**. Other untested patch versions, physical devices, Intel
execution and the Swift 6.0 compiler also remain unverified. A deployment-target
compilation does not fill these runtime coverage gaps.

SQLite data persistence across normal process termination is verified separately
from identifier stability. `PersistentIdentifier` equality/resolution between
containers or processes is not guaranteed. Native container retention on iOS
17.5 is observed, without establishing a permanent leak. Abrupt-crash/power-loss
durability, migrations and UIKit lifecycle coverage are not claimed.

These are disclosed evidence limits, not failing tests or demonstrated API
defects. Technical readiness does not imply that every declared deployment
version has been exercised. Publication retains these distinctions; no broader
compatibility guarantee is implied by the release.

## Authorized publication checks

The maintainer reviewed the scope and limitations and explicitly approved the
publication sequence. Verify these operations against the actual remote state:

1. Validate the release-documentation commit with both GitHub CI jobs; confirm
   local `main`, `origin/main`, remote `main` and the tested SHA agree.
2. Audit tracked files and reachable Git history, then make the existing
   repository public and configure its description and topics.
3. Create tag `0.1.0` on that SHA and publish `TypedSwiftData 0.1.0` with English
   release notes stating the guarantees, verified coverage and limitations.
4. Resolve exact version `0.1.0` from the public URL in a separate SwiftPM
   consumer, compile/run its typed-ID example, and inspect the tag-triggered CI.

Use the release page, its tag and the corresponding workflow runs as the
completion record. Earlier historical reports retain their original verdicts.

Repository description:

> Strongly typed model identifiers for Apple's SwiftData framework.

The workflow uses `xcode-27` and `macos-26`, explicitly selects Xcode 27/26.6,
checks actual versions and chooses an available simulator. It invokes the same
[verification entry point](../Scripts/verify.sh) used locally, including required
SQLite process checks on macOS and iOS. Missing tools/runtimes or unexpected
probe failures fail the job. No skip is used to hide a failing persistence test.
