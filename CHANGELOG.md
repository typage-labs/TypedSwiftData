# Changelog

## Unreleased — candidate 0.1.0

No version has been tagged or published.

### Added

- `ModelID<Model: PersistentModel>` with immutable native ID, synthesized
  Hashable/Sendable, and an internal raw-value initializer.
- `PersistentModel.typedID`, `fetchTypedIdentifiers(_:)`, and the typed
  `registeredModel(for:)` overload.
- Swift 6 compilation checks, negative fixtures checking their diagnostics,
  memory/SQLite/actor tests, and isolated native SwiftData probes.
- Protocol and availability-gated inheritance validation, compatibility evidence,
  and a GitHub verification workflow validated on Xcode 26.6 and 27.2.
- Explicit Xcode/simulator selection, private CI artifacts and summaries with
  actual toolchain versions and passed/skipped/failed runtime test counts.
- Separate SQLite process-restart checks and native-only memory diagnostics,
  validated locally on iOS 17.5, 18.5, 27.0, 27.1 and macOS 27.0.1.
- Hosted SQLite restart checks passed on Xcode 26.6 and 27.2 for their macOS
  hosts and installed iOS simulators; exact versions/counts are in the CI report.

### Corrected during review

- Observation-mode probes now fail on unexpected process failure or a missing
  completion marker, with a regression test for that failure path.
- Verification output no longer overwrites recorded evidence by default.
- Documentation distinguishes static type association, native behavior,
  experimental limitations, and potential framework anomalies.
- The equality fixture initializes its model container before creating models
  on iOS 17.5. SQLite tests separate functional persistence from an unsupported
  container release deadline; live database files are no longer unlinked.

### Deliberately excluded

- Existence resolution (`existingModel`), typed `model(for:)`, Codable,
  RawRepresentable, raw public factories, and store/permanence validation.

### Known limitations

- IDs can change after saving a new model; old copies are not updated.
- Registration is not proof of existence, and a cache miss is not proof of absence.
- Native ID lookups across SQLite container lifetimes failed in the tested cases.
- iOS 17.0/macOS 14 runtimes, Swift compiler 6.0, physical iOS hardware and Intel
  execution remain unverified. Full hosted results are in `docs/GITHUB_CI.md`.
