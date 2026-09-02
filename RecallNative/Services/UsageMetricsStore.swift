import Foundation

/// Persists aggregate creation activity that cannot be reconstructed after cards are deleted.
/// This mirrors Recall's `meta.totalCreated` field used by the launch-offer eligibility logic.
enum UsageMetricsStore {
    private static let totalCreatedKey = "recall.totalCreated.v1"

    static var totalCreated: Int {
        max(0, UserDefaults.standard.integer(forKey: totalCreatedKey))
    }

    static func recordCreated(_ count: Int) {
        guard count > 0 else { return }
        UserDefaults.standard.set(totalCreated + count, forKey: totalCreatedKey)
    }

    static func replaceTotalCreated(_ count: Int) {
        UserDefaults.standard.set(max(0, count), forKey: totalCreatedKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: totalCreatedKey)
    }
}
