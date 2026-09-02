import Foundation
import SwiftData

struct ICloudSyncService {
    private static let maxBytes = 900 * 1024
    private static let syncKey = "recall.native.sync.v2"
    private static let legacyKey = "recall.native.backup.v1"
    private static let lastSyncKey = "recall.native.lastSync.local"
    private static let deviceIDKey = "recall.native.deviceID"

    private let store = NSUbiquitousKeyValueStore.default

    struct SyncEnvelope: Codable, Equatable {
        let schemaVersion: Int
        let deviceID: String
        let updatedAt: Date
        let backupData: Data

        static let currentSchemaVersion = 1
    }

    enum SyncState: Equatable {
        case unavailable
        case noBackup
        case upToDate
        case remoteNewer
        case localOnly
    }

    func isAvailable() -> Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    func state() -> SyncState {
        guard isAvailable() else { return .unavailable }
        guard let envelope = remoteEnvelope() else {
            return store.data(forKey: Self.legacyKey) == nil ? .noBackup : .remoteNewer
        }
        guard let localDate = localLastSyncDate() else { return .remoteNewer }
        return envelope.updatedAt > localDate ? .remoteNewer : .upToDate
    }

    func push(context: ModelContext) throws -> Bool {
        guard isAvailable() else { return false }

        let now = Date.now
        let localDate = localLastSyncDate()

        // First sync on a device must never overwrite an existing cloud backup.
        // Restore it first, matching the original app's pull-before-push behavior.
        if localDate == nil {
            if let remote = remoteEnvelope() {
                guard remote.schemaVersion == SyncEnvelope.currentSchemaVersion else {
                    throw SyncError.unsupportedSchema(remote.schemaVersion)
                }
                try BackupService.restore(remote.backupData, context: context, replaceExisting: true)
            } else if let legacyData = store.data(forKey: Self.legacyKey) {
                try BackupService.restore(legacyData, context: context, replaceExisting: true)
            }
        } else if let remote = remoteEnvelope(), remote.updatedAt > localDate! {
            throw SyncError.remoteChanged(remote.updatedAt)
        }

        let data = try BackupService.makeBackup(context: context)
        guard data.count <= Self.maxBytes else { throw SyncError.tooLarge }

        let envelope = SyncEnvelope(
            schemaVersion: SyncEnvelope.currentSchemaVersion,
            deviceID: deviceID,
            updatedAt: now,
            backupData: data
        )
        let encoded = try JSONEncoder.sync.encode(envelope)
        guard encoded.count <= Self.maxBytes else { throw SyncError.tooLarge }

        store.set(encoded, forKey: Self.syncKey)
        store.synchronize()
        setLocalLastSync(now)
        return true
    }

    func pull(context: ModelContext, replaceExisting: Bool = true) throws -> Bool {
        guard isAvailable() else { return false }

        if let envelope = remoteEnvelope() {
            guard envelope.schemaVersion == SyncEnvelope.currentSchemaVersion else {
                throw SyncError.unsupportedSchema(envelope.schemaVersion)
            }
            try BackupService.restore(envelope.backupData, context: context, replaceExisting: replaceExisting)
            setLocalLastSync(envelope.updatedAt)
            return true
        }

        // One-time compatibility path for backups written by the earlier v1 implementation.
        guard let legacyData = store.data(forKey: Self.legacyKey) else { return false }
        try BackupService.restore(legacyData, context: context, replaceExisting: replaceExisting)
        let migratedAt = Date.now
        setLocalLastSync(migratedAt)
        return true
    }

    func synchronize() { store.synchronize() }

    func lastSyncDate() -> Date? { localLastSyncDate() }

    private var deviceID: String {
        if let existing = UserDefaults.standard.string(forKey: Self.deviceIDKey) { return existing }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: Self.deviceIDKey)
        return value
    }

    private func localLastSyncDate() -> Date? {
        UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date
    }

    private func setLocalLastSync(_ date: Date) {
        UserDefaults.standard.set(date, forKey: Self.lastSyncKey)
    }

    private func remoteEnvelope() -> SyncEnvelope? {
        guard let data = store.data(forKey: Self.syncKey) else { return nil }
        return try? JSONDecoder.sync.decode(SyncEnvelope.self, from: data)
    }

    enum SyncError: LocalizedError, Equatable {
        case tooLarge
        case remoteExists
        case remoteChanged(Date)
        case unsupportedSchema(Int)

        var errorDescription: String? {
            switch self {
            case .tooLarge:
                return "This library is too large for iCloud's key-value store. Use Export Backup instead."
            case .remoteExists:
                return "An iCloud backup already exists. Restore it before syncing this device for the first time."
            case .remoteChanged:
                return "The iCloud backup changed on another device. Restore it before replacing it with this device's data."
            case .unsupportedSchema(let version):
                return "This iCloud backup uses an unsupported sync format (v\(version)). Update Recall before syncing."
            }
        }
    }
}

private extension JSONEncoder {
    static var sync: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var sync: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
