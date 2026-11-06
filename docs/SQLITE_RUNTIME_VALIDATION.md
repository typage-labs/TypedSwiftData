# SQLite persistence and container lifetime — 2026-11-06

**iOS 17.5 now passes the applicable runtime suite and real process-restart
checks.** The former failure was a test oracle error: it required a native
`ModelContainer` to be deallocated within about one second before testing the
saved data. The container's observed retention is real; equating it with failed
persistence was incorrect. No public TypedSwiftData API was changed.

The initial failure and earlier evidence remain in
[the original iOS 17 diagnosis](IOS17_RUNTIME_VALIDATION.md). All results below
were captured locally before submitting the changes to GitHub. The subsequent
[CI report](GITHUB_CI.md) records hosted validation separately. Publication
information is maintained in the [README](../README.md); this report preserves
the experimental evidence from the local validation stage.

## Audit of the original failing test

`sqliteSaveDeleteAndReopen()` was read in full, together with `makeContainer`,
`makeContext`, the models and actor fixtures. Its references were:

| Reference | Lifetime / possible ownership |
| --- | --- |
| Local `container` | Strong only inside the synchronous `autoreleasepool` closure |
| Local `context` | Can own its container; only local to that closure; autosave explicitly disabled |
| Local `restaurant` | Native backing data may reference context/store state; only local to the closure |
| `releasedContainer`, `releasedContext` | Weak; assigning them does not preserve the referents |
| Returned `oldID` | A value containing a native `PersistentIdentifier`; its native internals could own state, so a no-ID control is necessary |
| `autoreleasepool` closure | Executes synchronously, does not escape and returns only the ID |
| Async test and `Task.sleep` loop | Retain the weak variables, ID and URL; no explicit container/context variable survives the closure |
| Actors | None in this test. `RestaurantWorker` instances belong to the separate SQLite actor test |
| Later containers | Created after the failing requirement, so cannot cause that earlier retention |
| Schema/fixtures | Local schema/configuration and stateless factory functions; no custom global container fixture |

The independent native-only diagnostic returns from a synchronous function,
retaining only weak container/context/model references (plus a raw ID in one
explicit control). It reproduces the retention with **no TypedSwiftData import,
no actor, no test framework, no escaping closure, and no retained identifier**.
On iOS 17.5, the context and model can both be gone while the container survives.
The evidence identifies native retention, rather than a strong reference left
in this test. The precise internal retaining object is not identified, and the
ten-second observation is not proof of a permanent leak.

## Why deallocation is not the persistence oracle

Apple documents `save()` as writing pending model changes to persistent storage,
and `ModelContainer` as coordinating reads and writes. The inspected public
contracts do not specify a deallocation deadline after saving or leaving a
Swift scope. Requiring weak references to become nil within one second was our
extra assumption, not the storage contract.
[Apple: save()](https://developer.apple.com/documentation/swiftdata/modelcontext/save()) ·
[Apple: ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer)

A second container in one process can verify visibility of saved data, but it
is not proof of an application restart. Conversely, a still-live first
container does not prove that saving or reading another container failed.
Actual process termination provides a clean boundary for the restart property
without assuming anything about ARC timing inside the old process.

## Restructured validation

1. **In-process behavior:** the test is now named
   `sqliteSaveDeleteAcrossContainers()`. It verifies the actual SQLite header,
   stored content, typed/native identifier parity, registration, pending versus
   saved deletion, and absence of deleted data through a fresh container. The
   existing cross-container raw/typed predicate comparison is preserved. It
   explicitly makes no process-restart or deterministic-deallocation claim.
2. **True process restart:** `Scripts/check_sqlite_restart.py` builds a separate
   client importing the actual library module. `SQLiteRestart.swift` runs in
   three sequential, separately awaited processes with distinct recorded PIDs:
   writer, reader/deleter, final reader. The writer saves a nonce-bearing
   Restaurant and an unrelated Customer sentinel. The next process verifies
   the exact persisted value, typed/native IDs and registration, then deletes
   and saves. The third process verifies that the Restaurant remains absent
   while the correct Customer sentinel survives. A fresh empty/wrong database
   cannot pass this check. The parent also checks the SQLite header and runs
   `PRAGMA integrity_check` after the Swift children exit.
3. **Memory lifetime:** `NativeContainerLifetime.swift` is built without linking
   TypedSwiftData and separately records six native controls. A retained weak
   reference is reported, not converted into a persistence failure. Crashes,
   timeouts and missing completion events still fail the diagnostic launcher.

No `ModelID` is serialized, reconstructed or passed between these processes.
Each process obtains fresh IDs from its models. The process check therefore
adds no guarantee of ID portability or identity stability across launches.

The two unit tests no longer unlink their temporary SQLite files in `defer`
while native stores/actors may still use them. They leave unique directories in
system temporary storage for later OS cleanup. The separate-process harness
owns its own directory and removes it only after all children have terminated
and checks pass. Failed or timed-out probe directories are retained as evidence.
The earlier `vnode unlinked while in use` warnings did not recur in the updated
unit-test logs.

`Scripts/verify.sh` requires the restart checks on macOS and its selected iOS
simulator, and the JSON summary includes their results. It verifies/boots the
already-selected simulator again before the extra checks, because Xcode can
shut down a destination it booted for testing. The first integration attempt
caught that shutdown and failed; after correcting the launcher, the complete
entry point exited **0**. No failure was ignored.

## Executed results

Toolchain: **Xcode 27.1 (27A9275)**, Apple **Swift 6.4**
(`swiftlang-6.4.0.34.1`, clang `2100.3.34.1`, driver `1.168.6`). Host:
**macOS 27.0.1 (26A434)** on Apple silicon. All builds use Swift 6, complete
concurrency checking and warnings as errors. Simulator SDK **27.1**, deployment
target **iOS 17.0**; native macOS SDK **27.0**, deployment target **macOS 14.0**.

| Actual runtime | Swift Testing passed / skipped / failed | Restart phases | SQLite integrity | Native lifetime controls |
| --- | --- | --- | --- | --- |
| iOS **17.5 (21F79)**, iPhone 15 Pro | **14 / 1 / 0** | **3 / 3 passed** | `ok` | 6 completed |
| iOS **18.5 (22F77)**, device named `18` | **14 / 1 / 0** | **3 / 3 passed** | `ok` | 6 completed |
| iOS **27.0 (24A434)**, iPhone 18 Pro | **15 / 0 / 0** | **3 / 3 passed** | `ok` | 6 completed |
| iOS **27.1 (24A94425)**, iPhone Duo | **15 / 0 / 0** | **3 / 3 passed** | `ok` | 6 completed |
| macOS **27.0.1 (26A434)** | **15 / 0 / 0** | **3 / 3 passed** | `ok` | 6 completed |

All simulator suite commands exited **0**, with no test filters. `.xcresult`
records each actual runtime/build and device. The existing inheritance test is
explicitly skipped on 17.5/18.5 because it requires iOS 26. Swift Testing's
15-discovered-tests line includes that skip; it is not counted as a pass here.

The full verification entry point additionally passed:

- 3 positive and 10 diagnostic-checked negative compilation fixtures **per SDK**
  (macOS and iOS), plus library-module compilation and a generic iOS device build.
- **4 Python harness regression tests**, including rejection of failed children,
  zero exits without completion evidence and mismatched store nonces.
- The existing **15 native macOS experiments**, including their specifically
  checked, isolated expected SIGTRAP.
- An additional real-reader negative control: opening a fresh empty store in
  `read-delete` mode exited **1** with `Saved row missing after writer exited`;
  no successful-completion event was emitted.

## Native memory observations

These are final observations in the recorded ten-second window, not universal
lifetime guarantees. “Released” means the diagnostic's weak references were
nil; times are sampling times, not exact deinitialization timestamps.

| Native operation, then leave the synchronous scope | iOS 17.5 | iOS 18.5 / 27.0 / 27.1 / macOS 27.0.1 |
| --- | --- | --- |
| Container only | Released at first observation | Released at first observation |
| Container + empty explicit context | Released at first observation | Released at first observation |
| Construct uninserted model | Container alive at 10 s; model/context nil | Released at first observation |
| Insert without saving | Container/context/model alive at 10 s | Container/context/model alive at 10 s |
| Insert + save, retain no ID | Container alive at 10 s; model/context nil | Released at first observation |
| Insert + save, retain raw ID | Container alive at 10 s; model/context nil | Released by the 0–1 s observation |

The unsaved-insertion retention occurs on every tested runtime. The difference
specific to 17.5 in this experiment is retention after model construction or
save even when no context/model/identifier remains in the caller. The snapshot
used for logging is also used for the diagnostic's termination condition, so a
release between two weak-reference reads cannot produce contradictory results.

## Reproduction and evidence

```sh
# Full local verification, including required process checks on macOS/iOS:
bash Scripts/verify.sh

# Explicit runtime; first boot an available simulator and await bootstatus:
python3 Scripts/check_sqlite_restart.py \
  --simulator 5A22FAA7-10CA-4A24-828D-1F4F81A3B79E \
  --label ios17.5 --lifetime

# Native host:
python3 Scripts/check_sqlite_restart.py --label macos --lifetime
```

Local raw evidence is ignored by Git under `.build/sqlite-validation/` and
`.build/verification/`. It includes each `.xcresult` and exported summary,
`runtime-suite-summaries.json`, `final-integration-summary.json`, compilation
commands, per-process outputs/nonces/PIDs, native lifetime observations, and
`negative-empty-store.json`. Earlier failed runs are preserved separately. The
source of every new probe/launcher is versionable in `Tests/RuntimeProbes/` and
`Scripts/`; none of the generated stores/binaries/reports is versioned.

## Scope of the conclusion

**iOS 17.5 is validated for the current API and the exercised memory, SQLite,
actor and process-restart scenarios.** Saved data and saved deletion survive
normal process termination and a fresh reader. Memory retention on that runtime
remains a documented native observation; TypedSwiftData promises no container
lifetime, existence, store membership or durable identifier semantics.

This is process-level persistence validation with bundled command-line clients
(`simctl spawn` on iOS), not a UIKit lifecycle test, migration test, abrupt-crash
or power-loss durability test. It does not serialize IDs or retest cross-launch
ID equality. iOS **17.0**, other untested patch versions, **macOS 14**, physical
iOS devices, Intel execution and the Swift 6.0 compiler remain unverified.
Subsequent hosted results and release readiness are recorded in the
[GitHub CI report](GITHUB_CI.md).
