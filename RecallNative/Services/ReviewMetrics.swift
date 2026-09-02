import Foundation

/// Pure review analytics shared by stats and future review-history surfaces.
struct ReviewMetrics {
    let reviews: [ReviewLog]
    private let calendar: Calendar
    private let dailyCounts: [Date: Int]

    init(reviews: [ReviewLog], calendar: Calendar = .current) {
        self.reviews = reviews
        self.calendar = calendar
        self.dailyCounts = reviews.reduce(into: [Date: Int]()) { counts, review in
            let day = calendar.startOfDay(for: review.reviewedAt)
            counts[day, default: 0] += 1
        }
    }

    var total: Int { reviews.count }

    var ratingCounts: [Int: Int] {
        reviews.reduce(into: [Int: Int]()) { counts, review in
            counts[review.rating, default: 0] += 1
        }
    }

    /// Average answer quality across the four user-facing review ratings.
    /// Returns zero when there are no reviews.
    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return Double(reviews.reduce(0) { $0 + $1.rating }) / Double(reviews.count)
    }

    /// Percentage of reviews rated Good or Easy.
    var positiveRate: Int {
        guard !reviews.isEmpty else { return 0 }
        let positive = reviews.reduce(into: 0) { count, review in
            if review.rating >= 3 { count += 1 }
        }
        return Int((Double(positive) / Double(reviews.count) * 100).rounded())
    }

    /// Number of reviews between two calendar days, inclusive.
    func count(from start: Date, through end: Date) -> Int {
        let lower = calendar.startOfDay(for: start)
        let upper = calendar.startOfDay(for: end)
        guard lower <= upper else { return 0 }
        return reviews.reduce(into: 0) { count, review in
            let day = calendar.startOfDay(for: review.reviewedAt)
            if day >= lower && day <= upper { count += 1 }
        }
    }

    func count(on date: Date) -> Int {
        dailyCounts[calendar.startOfDay(for: date), default: 0]
    }

    func counts(for dates: [Date]) -> [Int] {
        dates.map { count(on: $0) }
    }
}
