import Foundation
import SwiftData

struct ICloudSyncService: Sendable {
    private let store = NSUbiquitousKeyValueStore.default
    private let key = "recall.native.backup.v1"

    func isAvailable() -> Bool {
        let probe = "probe-\(UUID().uuidString)"
        store.set(probe, forKey: "recall.native.probe")
        store.synchronize()
        return store.string(forKey: "recall.native.probe") == probe
    }

    func push(context: ModelContext) throws -> Bool {
        guard isAvailable() else { return false }
        let data = try BackupService.makeBackup(context: context)
        store.set(data, forKey: key)
        store.synchronize()
        return true
    }

    func pull(context: ModelContext, replaceExisting: Bool = true) throws -> Bool {
        guard isAvailable(), let data = store.data(forKey: key) else { return false }
        try BackupService.restore(data, context: context, replaceExisting: replaceExisting)
        return true
    }

    func lastSyncDate() -> Date? { store.object(forKey: "recall.native.lastSync") as? Date }
    func markSynced() { store.set(Date.now, forKey: "recall.native.lastSync"); store.synchronize() }
}
