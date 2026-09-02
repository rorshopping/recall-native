import Foundation

/// Pure session-state helpers used by review UI and tests.
/// Keeping queue accounting separate from SwiftUI makes the review flow easier to reason about.
struct ReviewSessionState {
    private(set) var total: Int
    private(set) var reviewed: Int
    private(set) var completed: Int

    init(total: Int) {
        self.total = max(0, total)
        self.reviewed = 0
        self.completed = 0
    }

    var progress: Int {
        guard total > 0 else { return 0 }
        return min(completed + 1, total)
    }

    var progressFraction: Double {
        guard total > 0 else { return 0 }
        return Double(progress) / Double(total)
    }

    mutating func recordReview(completedCard: Bool) {
        reviewed += 1
        if completedCard {
            completed = min(completed + 1, total)
        }
    }

    mutating func reset(total: Int) {
        self.total = max(0, total)
        reviewed = 0
        completed = 0
    }
}

extension ReviewSessionState: Equatable {}
