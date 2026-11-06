import Foundation
import SwiftData

// Native-only diagnostic, deliberately not linked to TypedSwiftData. Retention
// is observed independently of persistence; no release deadline is a test oracle.
@main enum NativeContainerLifetime {
    @MainActor final class References {
        weak var container: ModelContainer?
        weak var context: ModelContext?
        weak var model: Restaurant?
        var retainedID: PersistentIdentifier?
    }

    static func emit(_ fields: [String: Any]) {
        let data = try! JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
        FileHandle.standardOutput.write(data + Data([10]))
    }

    @MainActor static func populate(_ url: URL, mode: String) throws -> References {
        let references = References()
        try autoreleasepool {
            let schema = Schema([Restaurant.self, Customer.self])
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            references.container = container
            if mode == "container-only" { return }
            let context = ModelContext(container)
            context.autosaveEnabled = false
            references.context = context
            if mode == "context-only" { return }
            let model = Restaurant(name: "Native")
            references.model = model
            if mode == "model-only" { return }
            context.insert(model)
            if mode == "insert" { return }
            try context.save()
            if mode == "save-retain-id" { references.retainedID = model.persistentModelID }
        }
        return references
    }

    @MainActor static func main() async {
        do {
            let mode = CommandLine.arguments[1]
            guard ["container-only", "context-only", "model-only", "insert", "save", "save-retain-id"].contains(mode) else { exit(2) }
            let references = try populate(URL(fileURLWithPath: CommandLine.arguments[2]), mode: mode)
            for second in 0...10 {
                // Use the same observation for logging and termination: native
                // work can release a weak referent between two separate reads.
                let containerNil = references.container == nil
                let contextNil = references.context == nil
                let modelNil = references.model == nil
                emit(["event": "lifetime", "seconds": second,
                      "containerNil": containerNil, "contextNil": contextNil,
                      "modelNil": modelNil, "retainedID": references.retainedID != nil])
                if containerNil && contextNil && modelNil { break }
                if second < 10 { try await Task.sleep(for: .seconds(1)) }
            }
            emit(["event": "completed", "mode": mode, "pid": ProcessInfo.processInfo.processIdentifier,
                  "os": ProcessInfo.processInfo.operatingSystemVersionString])
        } catch {
            emit(["event": "failure", "error": String(describing: error)])
            exit(1)
        }
    }
}
