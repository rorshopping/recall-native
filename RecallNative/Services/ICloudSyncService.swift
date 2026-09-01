import Foundation
import SwiftData

struct ICloudSyncService {
    private static let maxBytes = 900 * 1024
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
        guard data.count <= Self.maxBytes else { throw SyncError.tooLarge }
        store.set(data, forKey: key); store.set(Date.now, forKey: "recall.native.lastSync"); store.synchronize(); return true
    }
    func pull(context: ModelContext, replaceExisting: Bool = true) throws -> Bool {
        guard isAvailable(), let data = store.data(forKey: key) else { return false }
        try BackupService.restore(data, context: context, replaceExisting: replaceExisting); store.set(Date.now, forKey: "recall.native.lastSync"); store.synchronize(); return true
    }
    func synchronize() { store.synchronize() }
    func lastSyncDate() -> Date? { store.object(forKey: "recall.native.lastSync") as? Date }
    enum SyncError: LocalizedError { case tooLarge; var errorDescription: String? { "This library is too large for iCloud's key-value store. Use Export Backup instead." } }
}
