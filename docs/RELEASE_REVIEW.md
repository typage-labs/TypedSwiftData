# Final review before 0.1.0

Historical prepublication review, before private GitHub repository creation.
See [GitHub CI validation](GITHUB_CI.md) for the subsequent hosted results and
current release-readiness assessment. This record is retained as local evidence.

Review date: **2026-11-05**. Verdict: **NOT READY** for publication. The retained
API is useful and the local implementation checks pass; minimum-runtime and
minimum-toolchain coverage, a hosted CI run, and human release approval remain
open. This review prepares those steps and does not publish anything.

## Findings and corrections

No implementation defect requiring a change to the four production APIs was
found in this review. Both production Swift files remain unchanged. Their exact
signatures are in [API_DESIGN.md](API_DESIGN.md).

| API | Exact static guarantee | Native behavior and limits |
| --- | --- | --- |
| `ModelID<Model>` | Immutable native value tagged with the static model type; Hashable and Sendable without storing a model; external raw initialization rejected | No row, store, permanence, or dynamic-class validation; equality/hashing are native |
| `PersistentModel.typedID` | Returns `ModelID<Self>` in concrete/generic use | Captures the current value without save/remapping; direct access on `any PersistentModel` is rejected |
| `fetchTypedIdentifiers` | Descriptor type determines the array element's model type | One native identifier fetch and a map; descriptor, native polymorphism, ordering, pending changes, and errors preserved |
| `registeredModel(for:)` | Typed argument determines the optional result type | Direct native cache lookup, without fetch, existence check, deletion filtering, or retention |

The distinct typed-fetch name prevents return-type-only overload ambiguity.
The typed-registration overload is distinguished by its argument type, so the
native raw call remains available. Tests demonstrate inferred results as well
as explicit annotations. There are no casts in production code, no public raw
constructor, and no custom/unchecked Sendable conformance.

Two previously untested boundaries are now covered. Protocol-constrained calls
work and an existential can be opened by a generic function; direct existential
`typedID` access does not work. With availability-gated native inheritance,
`Cafe.typedID` is `ModelID<Cafe>`, an explicitly upcast `Venue` yields
`ModelID<Venue>`, and wrapper covariance is rejected. A base-class ID can denote
a subclass row. The API promises static association, not exact dynamic class.

One **verification defect** was fixed: observation-mode native probes previously
returned success after unexpected subprocess failures. All modes now check
completion or the specific deliberate SwiftData trap. A regression test runs
the probe harness against `/usr/bin/false` and requires the run and every probe
to be reported as failed. No arbitrary nonzero exit is accepted as a native
crash reproduction.

Two maintainability gaps were corrected: script output now defaults to ignored
`.build/verification` instead of overwriting historical evidence; the compilation
script derives the host architecture instead of assuming arm64. A single local
verification entry point is shared with the prepared CI. No production API or
dependency was added.

The new runtime existential assertion initially hit Swift Testing macro
expansion: wrapping the generic call directly in `#expect` changed how the
existential was opened. Evaluating its Bool result before `#expect` resolved the
test expression without changing the API or weakening the assertion.

## Native observations: contract versus experiment

| Observation | Apple-documented part | Reproduced here | Classification / boundary |
| --- | --- | --- | --- |
| Temporary ID replaced after save | Native identifiers are initially temporary and receive a permanent value on first save; temporary copies must not become durable keys | IDs changed for both models; captured copies remained obsolete and missed subsequent lookup | Documented lifecycle; exact timing/equality/cache details remain measured behavior, not a new universal wrapper contract |
| SQLite reopen lookup misses | No cited Apple contract establishes that the particular retained native ID must resolve across independently created containers | Weak refs released; unfiltered fetch reads the row, old-ID predicate returns 0, new-ID predicate returns 1 | Potential SwiftData identity/lookup anomaly; a reproducible limitation of this resolver approach, not a confirmed Apple bug diagnosis |
| Two containers, same SQLite file | Container identity and native ID values are not validated by the wrapper | Same store ID, distinct native values; old-ID lookup misses while the row exists | Same potential anomaly; do not infer that all cross-container use always fails |
| `model(for:)` after deletion | For an unknown ID, Apple documents an unsaved model carrying that ID | Returned model casts successfully; property read traps with invalidated backing data | Placeholder behavior is documented; the observed fatal-access outcome is a runtime hazard, not an existence API contract |
| Registered then pending-deleted model | Deletion is persisted on a subsequent save; registration lookup returns a known model or nil | Pending-deleted instance remains registered; after save, lookup misses and retained `isDeleted` resets | Cache/lifecycle detail observed on tested versions; no universal guarantee of exact eviction or flag-reset timing |
| Registered model deleted by another context | Registration is not documented as a current storage-existence check | Reader cache still holds the instance while a fresh predicate returns 0 | Known limitation of cache-based existence reasoning; not itself proof of a framework bug |
| Registration disappears after reference release | Apple does not promise object retention in the cited lookup documentation | Reader lookup becomes nil after the strong reference is dropped | Non-contractual cache lifetime observation |

Primary sources: [insert(_:)](https://developer.apple.com/documentation/swiftdata/modelcontext/insert(_:)),
[isTemporary](https://developer.apple.com/documentation/swiftdata/persistentidentifier/istemporary),
[model(for:)](https://developer.apple.com/documentation/swiftdata/modelcontext/model(for:)),
[registeredModel(for:)](https://developer.apple.com/documentation/swiftdata/modelcontext/registeredmodel(for:)),
[delete(_:)](https://developer.apple.com/documentation/swiftdata/modelcontext/delete(_:)).

`existingModel` remains excluded. A predicate is more informative than a cast,
but returning nil for the reopened existing row would not establish the proposed
general existence semantics. No parsing, decoding/reconstruction, arbitrary
store validation, or broad workaround was added.

The existing `SwiftDataExperiments` target is already independent of
TypedSwiftData (no import or target dependency). It keeps the two native models
and runs one selected scenario per process. Use `swift run SwiftDataExperiments
reopen`, `same-store-containers`, `pending-delete`, or `model-deleted-property` as
the final argument to reproduce each case; the last case intentionally crashes.
The isolated runner records stdout before traps. Another implementation copy
was unnecessary for this audit.

## Executed checks and clean checkout

A local Git seed was created from the package sources, excluding `.build`,
`.swiftpm`, `.git`, and derived data. It was committed **only in the temporary
verification directory**, then cloned locally into a new checkout. The package
directory itself was not initialized as a Git repository. No network remote was
created or used. The clean checkout ran the same script prepared for CI.

Evidence in [clean-checkout.json — local evidence](evidence/README.md) identifies
the snapshot and source hashes. Initial and final Git status are checked as
clean; generated files remain ignored. The report is finalized after execution,
not inferred from previous build artifacts.

| Final review check | Actual result | Evidence |
| --- | --- | --- |
| Clean CI script | Exit 0; strict compiler checks and actual iOS build | [log — local evidence](evidence/README.md) |
| macOS 27.0.1 runtime | 15 executed, 0 failures | [log — local evidence](evidence/README.md) |
| iOS 27.0 simulator | 15 executed, 0 failures | [log — local evidence](evidence/README.md) |
| iOS 18.5 simulator | 14 executed, 1 inheritance test skipped, 0 failures | [log — local evidence](evidence/README.md) |
| Harness regression | 1 unittest passed, checking failed-probe rejection | [log — local evidence](evidence/README.md) |
| macOS SDK 27.0 external compiler checks | 1 module, 3 positive fixtures, 10 negative fixtures verified | [JSON — local evidence](evidence/README.md) |
| iOS SDK 27.1 external compiler checks | Same 14 invocations verified, target iOS 17.0 | [JSON — local evidence](evidence/README.md) |
| macOS SDK 26.5 external compiler checks | Same 14 invocations verified with Xcode 27.1 macro plugin | [JSON — local evidence](evidence/README.md) |
| Native reference probes, macOS SDK 27 | 15/15 reference checks matched | [JSON — local evidence](evidence/README.md) |
| Native reference probes, macOS SDK 26.5 | 15/15 reference checks matched on the same host runtime | [JSON — local evidence](evidence/README.md) |
| Native reference probes, iOS 27.0 | 15/15 reference checks matched | [JSON — local evidence](evidence/README.md) |
| Native reference probes, iOS 18.5 | 15/15 reference checks matched | [JSON — local evidence](evidence/README.md) |

That is **44 executed Swift runtime tests and one availability skip**, **9
positive and 30 negative client fixture checks**, and 60 reference-probe
executions including four deliberate SIGTRAPs. The CI script additionally ran
the native process checks in observation mode. Matching a reference that
contains an anomaly or trap does not mean SwiftData resolution succeeded.

The negative fixtures check error count, exact file and line, and a diagnostic
pattern identifying the offending types or access/conformance rule. The
`existingModel` absence check is explicitly distinct from a type-mismatch check.
Swift Testing reports 15 discovered tests on iOS 18.5 even though one is skipped;
it is not counted as 15 executed tests here.

No Swift compiler warning was accepted. Xcode may emit its SDK-build-number
parsing diagnostic and an AppIntents metadata-extraction warning for the test
runner without an AppIntents dependency; these are recorded as tool diagnostics,
not hidden or represented as Swift compiler failures. Hosted CI execution is
still unverified; local YAML parsing and shell syntax checks are narrower checks.

An initial iOS native-probe batch failed to launch because the simulator was
shut down after Xcode testing (`simctl` exit 149, no SwiftData events). The
failure was correctly rejected and [retained — local evidence](evidence/README.md).
After explicitly booting the devices and waiting for boot completion, both final
iOS probe batches passed. Those failed launches are not counted among the 60
executed reference probes or mistaken for the expected SwiftData crash.

## Comparison and originality

The phantom-type idea is established; TypedSwiftData makes no novelty claim.

| Reference | Overlap | Relevant difference |
| --- | --- | --- |
| [Harumaru169's gist, 28 March 2024](https://gist.github.com/Harumaru169/3faea256a3c242553dc030594e66db99) | SwiftData phantom identifier and context conveniences | Broader conformances and cast-based lookup; no packaged public-module contract. |
| [John Sundell's Identity](https://github.com/JohnSundell/Identity) | Generic identifiers associated with model types | General configurable raw identity and conditional serialization; no SwiftData lifecycle/registration semantics supplied by that abstraction. |
| [Matt Rubin's Identifier](https://github.com/mattrubin/Identifier) | Model-typed identifiers, Hashable/Sendable | UUID-backed identity with serialization, independent of SwiftData's native IDs. It addresses a different identity need. |

In that gist, the raw initializer and type default to **internal**, not public.
If integrated into an app module, its callers in that module can associate an
arbitrary raw ID with a model type. Our library-module boundary rejects that
construction from consumers. The gist's Codable conformance supplies no
model-association validation; this is a source-level inference, not a decoding
test executed here. We deliberately omit Codable. Its `as? T` lookup tests the
returned object's type, which does not prove a row exists. We omit that
convenience; our isolated native probes demonstrate the hazard independently.

The implementation existed before this review consulted those sources. No
third-party source was copied into the package during either phase. The gist
page shows no license notice in its single displayed source file; it was used
only for comparison, not treated as permission to copy. The comparison does not
claim that the other projects were compiled or audited here.

The local source history in this chat and the reviewed files support an
independently authored implementation. This is a provenance review of this
work, not an exhaustive proof that no similar code exists anywhere. No external
source implementation, dependency, generated custom macro, or TypedCoreData code
is included. No TypedCoreData file was read or changed.

`LICENSE` matches the canonical Apache 2.0 text byte for byte. The README's
license and copyright notice are consistent. [License verification — local evidence](evidence/README.md)
records its SHA-256 and the canonical source. Maintainer confirmation of
contributor/copyright authorization remains a publication checklist item.

## Remaining release conditions and verdict

The [compatibility matrix](COMPATIBILITY.md) keeps four dimensions separate:
SDK/deployment-target compilation, runtime execution, compiler version, and
Xcode version. iOS 17 and macOS 14 execution, Swift compiler 6.0, and Xcode 26.6
remain unverified. Other untested cases include physical iOS hardware, custom
stores, CloudKit, migration, and multiple stores. These features are not newly
promised by the wrapper.

**NOT READY**: the local candidate is suitable for maintainer review, but the
minimum-support coverage or support-policy decision, actual hosted CI run,
provenance approval, final release-commit review, and explicit human publication
approval remain open. The full [checklist and suggested GitHub metadata](RELEASE_CHECKLIST.md)
are prepared. No release, tag, remote repository, or push was performed.
