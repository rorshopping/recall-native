import Foundation

/// Pure session-state helpers used by review UI and tests.
/// Keeping queue accounting separate from SwiftUI makes the review flow easier to reason about.
struct ReviewSessionState {
    private(set) var total: Int
    private(set) var reviewed: Int
    private(set) var completed: Int
    private(set) var ratingCounts: [Int: Int]

    init(total: Int) {
        self.total = max(0, total)
        self.reviewed = 0
        self.completed = 0
        self.ratingCounts = [:]
    }

    /// Number of cards completed in the original session queue.
    /// Repeating an Again card does not advance this value, so the progress indicator
    /// reflects actual completion rather than the position of the currently visible card.
    var progress: Int {
        guard total > 0 else { return 0 }
        return min(completed, total)
    }

    /// Number of cards still outstanding in the original session queue.
    var remaining: Int { max(0, total - progress) }

    /// Whether every card from the original queue has been completed.
    var isComplete: Bool { total > 0 && progress >= total }

    var progressFraction: Double {
        guard total > 0 else { return 0 }
        return Double(progress) / Double(total)
    }

    /// Number of rated responses for one of the four supported grades.
    func ratingCount(_ rating: Int) -> Int {
        ratingCounts[rating, default: 0]
    }

    /// Percentage of session responses rated Good or Easy.
    /// Returns zero until at least one response has been recorded.
    var positiveRate: Int {
        guard reviewed > 0 else { return 0 }
        let positive = ratingCount(3) + ratingCount(4)
        return Int((Double(positive) / Double(reviewed) * 100).rounded())
    }

    /// Percentage of the original queue that has been completed.
    var completionRate: Int {
        guard total > 0 else { return 0 }
        return Int((Double(progress) / Double(total) * 100).rounded())
    }

    mutating func recordReview(completedCard: Bool, rating: Int? = nil) {
        reviewed += 1
        if let rating, (1...4).contains(rating) {
            ratingCounts[rating, default: 0] += 1
        }
        if completedCard {
            completed = min(completed + 1, total)
        }
    }

    mutating func reset(total: Int) {
        self.total = max(0, total)
        reviewed = 0
        completed = 0
        ratingCounts = [:]
    }
}

extension ReviewSessionState: Equatable {}
