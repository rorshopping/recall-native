import Foundation

/// Pure review analytics shared by stats and review-history surfaces.
struct ReviewMetrics {
    let reviews: [ReviewLog]
    private let calendar: Calendar
    private let aggregateHistory: [Date: Int]
    private let dailyCounts: [Date: Int]

    init(reviews: [ReviewLog], aggregateHistory: [Date: Int] = [:], calendar: Calendar = .current) {
        self.reviews = reviews
        self.calendar = calendar
        self.aggregateHistory = aggregateHistory.reduce(into: [:]) { result, entry in
            result[calendar.startOfDay(for: entry.key)] = max(0, entry.value)
        }
        var counts = self.aggregateHistory
        for review in reviews {
            let day = calendar.startOfDay(for: review.reviewedAt)
            counts[day, default: 0] += 1
        }
        self.dailyCounts = counts
    }

    /// Total completed reviews, including aggregate history imported from the original Recall backup format.
    var total: Int { reviews.count + aggregateHistory.values.reduce(0, +) }

    /// Reviews with an actual rating. Imported aggregate history has no per-review rating, so it is excluded.
    var ratedTotal: Int { reviews.count }

    var hasUnratedHistory: Bool { total > ratedTotal }

    var ratingCounts: [Int: Int] {
        reviews.reduce(into: [Int: Int]()) { counts, review in
            counts[review.rating, default: 0] += 1
        }
    }

    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return Double(reviews.reduce(0) { $0 + $1.rating }) / Double(reviews.count)
    }

    var positiveRate: Int {
        guard !reviews.isEmpty else { return 0 }
        let positive = reviews.reduce(into: 0) { count, review in
            if review.rating >= 3 { count += 1 }
        }
        return Int((Double(positive) / Double(reviews.count) * 100).rounded())
    }

    func ratingPercentage(_ rating: Int) -> Int {
        guard !reviews.isEmpty else { return 0 }
        return Int((Double(ratingCounts[rating, default: 0]) / Double(reviews.count) * 100).rounded())
    }

    func count(inLastDays days: Int, endingOn date: Date = .now) -> Int {
        guard days > 0 else { return 0 }
        let end = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: end) ?? end
        return count(from: start, through: end)
    }

    func streak(endingOn date: Date = .now) -> Int {
        var day = calendar.startOfDay(for: date)
        guard dailyCounts[day, default: 0] > 0 else { return 0 }
        var result = 0
        while dailyCounts[day, default: 0] > 0 {
            result += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return result
    }

    func activeStreak(endingOn date: Date = .now) -> Int {
        let today = calendar.startOfDay(for: date)
        if dailyCounts[today, default: 0] > 0 { return streak(endingOn: today) }
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
        return streak(endingOn: yesterday)
    }

    func count(from start: Date, through end: Date) -> Int {
        let lower = calendar.startOfDay(for: start)
        let upper = calendar.startOfDay(for: end)
        guard lower <= upper else { return 0 }
        return dailyCounts.reduce(into: 0) { count, entry in
            if entry.key >= lower && entry.key <= upper { count += entry.value }
        }
    }

    func count(on date: Date) -> Int {
        dailyCounts[calendar.startOfDay(for: date), default: 0]
    }

    func counts(for dates: [Date]) -> [Int] {
        dates.map { count(on: $0) }
    }
}
