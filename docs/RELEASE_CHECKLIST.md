# Candidate 0.1.0 — publication checklist

Status: **NOT READY** pending the remaining conditions and hosted results in
[GitHub CI validation](GITHUB_CI.md). The maintainer authorized private repository
creation and CI validation. Public visibility, a version tag, and a GitHub
Release still require separate approval.

## Prepared locally

- [x] Four-element API reviewed without adding production functionality.
- [x] Internal constructor, immutable value, no Codable or raw public factory.
- [x] Native behavior and lack of existence/permanence/container guarantees explained.
- [x] Before/after examples checked by positive and negative compilation fixtures.
- [x] Protocol and inherited-model coverage added with availability gates.
- [x] Local install instructions and explicitly prospective remote instructions.
- [x] [Changelog](../CHANGELOG.md), [compatibility matrix](COMPATIBILITY.md),
  [review](RELEASE_REVIEW.md), and original [evidence](IMPLEMENTATION_VERIFICATION.md).
- [x] Canonical Apache 2.0 license and implementation provenance reviewed.
- [x] Local CI entry point and GitHub workflow prepared; no publishing steps.

## Conditions still to satisfy

- [ ] Exercise memory, SQLite, actor, and native probes on the minimum advertised
  runtimes, **iOS 17 and macOS 14**, or explicitly revise the intended support
  policy and obtain maintainer acceptance of the remaining coverage gap.
- [ ] Test **Xcode 26.6** before promoting it from an intended floor to a verified
  toolchain. If Swift compiler 6.0 compatibility is advertised, actually test it;
  `swift-tools-version: 6.0` and `-swift-version 6` alone do not establish that.
- [ ] Run both jobs of the prepared
  workflow on the real GitHub runner. Confirm the selected Xcode, SDKs, runtime,
  tests, and uploaded evidence. Record actual results in the CI report.
- [ ] Review the source provenance record and confirm the intended copyright
  holder/contributor authorization. No third-party implementation is included.
- [ ] Approve the documented scope: IDs are typed snapshots and registration is
  a native cache lookup. Keep `existingModel` excluded.
- [ ] Review the final diff, public declarations, changelog, and compatibility
  wording on the exact commit intended for release.
- [x] Verify `typage-labs/TypedSwiftData` exists with PRIVATE visibility and the
  intended description. No unavailable version is advertised as released.
- [ ] Obtain explicit human approval for the later publication operation.

Only after approval: finalize the version entry, create the release commit/tag
according to the maintainer's process, check remote SPM resolution, and publish.
None of those operations is part of this task.

## Prepared GitHub metadata

Suggested description:

> Model-typed SwiftData identifiers with Swift 6 concurrency checks and native API semantics.

Suggested topics: `swift`, `swiftdata`, `swift-package-manager`, `type-safety`,
`phantom-types`, `concurrency`, `ios`, `macos`.

Do not describe the package as a durable identity system, existence resolver,
cross-store ID solution, or a new invention of typed identifiers.

## CI scope

[verify.yml](../.github/workflows/verify.yml) uses the requested `xcode-27` and
`macos-26` runner labels with Xcode 27 and 26.6 respectively, official checkout/upload actions, read-only repository permission,
and [Scripts/verify.sh](../Scripts/verify.sh). The script records actual versions,
verifies the selected Xcode version, runs compiler/runtime checks, builds for a real iOS target,
and chooses an installed recent simulator. A missing required SDK/runtime fails
the job instead of counting as successful compatibility validation.

The local execution of that script is evidence about this machine. A matching
runner label is not proof of the same host or Xcode version. The selected
simulator is recorded; the CI does not masquerade as minimum-runtime coverage.
Exact native reference snapshots are opt-in with `--verify-reference` because
OS behavior may change; process failures and the known crash diagnostic are
checked in all modes. Runtime tests contain explicit observations which may
need investigation on a new OS, not blind expectation changes.

Workflow YAML parsing and shell syntax were checked locally. The hosted run
status is reported separately; branch protection and repository secrets are
outside this task. The workflow does not publish anything.

References: [GitHub runner labels](https://docs.github.com/en/actions/reference/runners/github-hosted-runners),
[checkout v7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1),
[upload-artifact v7.0.2](https://github.com/actions/upload-artifact/releases/tag/v7.0.2).
