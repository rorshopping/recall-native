import Foundation

/// Pure review analytics shared by stats and future review-history surfaces.
struct ReviewMetrics {
    let reviews: [ReviewLog]
    private let calendar: Calendar

    init(reviews: [ReviewLog], calendar: Calendar = .current) {
        self.reviews = reviews
        self.calendar = calendar
    }

    var total: Int { reviews.count }

    var ratingCounts: [Int: Int] {
        reviews.reduce(into: [Int: Int]()) { counts, review in
            counts[review.rating, default: 0] += 1
        }
    }

    var positiveRate: Int {
        guard !reviews.isEmpty else { return 0 }
        let positive = reviews.reduce(into: 0) { count, review in
            if review.rating >= 3 { count += 1 }
        }
        return Int((Double(positive) / Double(reviews.count) * 100).rounded())
    }

    func count(on date: Date) -> Int {
        reviews.reduce(into: 0) { count, review in
            if calendar.isDate(review.reviewedAt, inSameDayAs: date) { count += 1 }
        }
    }

    func counts(for dates: [Date]) -> [Int] {
        dates.map { count(on: $0) }
    }
}
