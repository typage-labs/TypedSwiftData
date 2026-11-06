import Foundation
import SwiftData
import TypedSwiftData

// Compiled as an external client of the real library. Each invocation owns a
// fresh process; no model, context, container or ModelID crosses that boundary.
@main enum SQLiteRestart {
    struct Failure: Error { let message: String }

    static func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw Failure(message: message) }
    }

    static func emit(_ fields: [String: Any]) {
        let data = try! JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
        FileHandle.standardOutput.write(data + Data([10]))
    }

    @MainActor static func main() {
        do {
            guard CommandLine.arguments.count == 4 else { throw Failure(message: "Expected phase, store URL and nonce") }
            let phase = CommandLine.arguments[1]
            let url = URL(fileURLWithPath: CommandLine.arguments[2])
            let nonce = CommandLine.arguments[3]
            let schema = Schema([Restaurant.self, Customer.self])
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            context.autosaveEnabled = false
            switch phase {
            case "write":
                try check(context.fetch(FetchDescriptor<Restaurant>()).isEmpty, "Initial store is not empty")
                context.insert(Restaurant(name: nonce))
                context.insert(Customer(name: "customer-" + nonce))
                try context.save()
                let row = try context.fetch(FetchDescriptor<Restaurant>()).first
                try check(row?.name == nonce, "Writer did not save the expected value")
                try check(context.fetchTypedIdentifiers(FetchDescriptor<Restaurant>()).map(\.rawValue)
                          == context.fetchIdentifiers(FetchDescriptor<Restaurant>()), "Writer typed/native mismatch")
            case "read-delete":
                let rows = try context.fetch(FetchDescriptor<Restaurant>())
                try check(rows.count == 1 && rows.first?.name == nonce, "Saved row missing after writer exited")
                guard let row = rows.first else { throw Failure(message: "Missing row") }
                let id = row.typedID
                try check(context.fetchTypedIdentifiers(FetchDescriptor<Restaurant>()) == [id], "Reopened typed IDs mismatch")
                try check(context.fetchIdentifiers(FetchDescriptor<Restaurant>()) == [id.rawValue], "Reopened native IDs mismatch")
                try check(context.registeredModel(for: id) === row, "Reopened registration mismatch")
                context.delete(row)
                try check(context.fetchTypedIdentifiers(FetchDescriptor<Restaurant>()).isEmpty, "Pending deletion not reflected")
                var stored = FetchDescriptor<Restaurant>()
                stored.includePendingChanges = false
                try check(context.fetchTypedIdentifiers(stored) == [id], "Unsaved deletion changed stored rows")
                try context.save()
                try check(context.registeredModel(for: id) == nil, "Saved deletion still registered")
            case "verify-deleted":
                try check(context.fetch(FetchDescriptor<Restaurant>()).isEmpty, "Deleted row returned after deleting process exited")
                try check(context.fetchTypedIdentifiers(FetchDescriptor<Restaurant>()).isEmpty, "Deleted ID returned after restart")
            default:
                throw Failure(message: "Unknown phase: " + phase)
            }
            let customers = try context.fetch(FetchDescriptor<Customer>())
            try check(customers.count == 1 && customers.first?.name == "customer-" + nonce,
                      "Sentinel missing: wrong store, lost data or unintended deletion")
            emit(["event": "completed", "phase": phase, "pid": ProcessInfo.processInfo.processIdentifier,
                  "nonce": nonce, "restaurants": try context.fetchCount(FetchDescriptor<Restaurant>()),
                  "customers": customers.count, "os": ProcessInfo.processInfo.operatingSystemVersionString])
        } catch {
            emit(["event": "failure", "error": String(describing: error)])
            exit(1)
        }
    }
}
