# Candidate 0.1.0 — release checklist

Technical status: **READY FOR PUBLIC RELEASE**, with evidence in the
[CI report](GITHUB_CI.md). The maintainer authorized committing and pushing to
the private repository. Public visibility, a version tag and a GitHub Release
remain separate human decisions and are not authorized by this validation task.

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
- [x] Repository private, branch `main`, normal push only; workflow permissions
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
version has been exercised. The maintainer's publication decision must retain
these distinctions; no broader compatibility guarantee is authorized here.

## Human publication decision

- [ ] Review the final commit, changelog, documented API scope and compatibility
  limits, and approve publication explicitly.
- [ ] Only after that separate approval: perform the requested visibility/tag/
  release operations and verify version-based SwiftPM resolution.

No tag or release exists yet; `0.1.0` remains a candidate. The current private
repository description is:

> Strongly typed model identifiers for Apple's SwiftData framework.

The workflow uses `xcode-27` and `macos-26`, explicitly selects Xcode 27/26.6,
checks actual versions and chooses an available simulator. It invokes the same
[verification entry point](../Scripts/verify.sh) used locally, including required
SQLite process checks on macOS and iOS. Missing tools/runtimes or unexpected
probe failures fail the job. No skip is used to hide a failing persistence test.
