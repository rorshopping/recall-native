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

    /// Percentage for one rating, rounded to the nearest whole number.
    func ratingPercentage(_ rating: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(ratingCounts[rating, default: 0]) / Double(total) * 100).rounded())
    }

    /// Number of reviews in the trailing calendar-day window ending on `date`.
    /// A value of one counts only the calendar day containing `date`.
    func count(inLastDays days: Int, endingOn date: Date = .now) -> Int {
        guard days > 0 else { return 0 }
        let end = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: end) ?? end
        return count(from: start, through: end)
    }

    /// Number of consecutive calendar days with at least one review, ending on `date`.
    /// If there was no review on `date`, the streak is zero.
    func streak(endingOn date: Date = .now) -> Int {
        var day = calendar.startOfDay(for: date)
        guard dailyCounts[day, default: 0] > 0 else { return 0 }

        var result = 0
        while dailyCounts[day, default: 0] > 0 {
            result += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, from: day) else { break }
            day = previous
        }
        return result
    }

    /// The user's active streak, allowing the current day to remain at risk until midnight.
    /// If there is no review today, yesterday's consecutive streak is returned.
    func activeStreak(endingOn date: Date = .now) -> Int {
        let today = calendar.startOfDay(for: date)
        if dailyCounts[today, default: 0] > 0 {
            return streak(endingOn: today)
        }
        guard let yesterday = calendar.date(byAdding: .day, value: -1, from: today) else { return 0 }
        return streak(endingOn: yesterday)
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
