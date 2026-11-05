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
  and a prepared GitHub verification workflow.

### Corrected during review

- Observation-mode probes now fail on unexpected process failure or a missing
  completion marker, with a regression test for that failure path.
- Verification output no longer overwrites recorded evidence by default.
- Documentation distinguishes static type association, native behavior,
  experimental limitations, and potential framework anomalies.

### Deliberately excluded

- Existence resolution (`existingModel`), typed `model(for:)`, Codable,
  RawRepresentable, raw public factories, and store/permanence validation.

### Known limitations

- IDs can change after saving a new model; old copies are not updated.
- Registration is not proof of existence, and a cache miss is not proof of absence.
- Native ID lookups across SQLite container lifetimes failed in the tested cases.
- iOS 17/macOS 14 runtimes, Swift compiler 6.0, and Xcode 26.6 remain unverified.
