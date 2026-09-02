import XCTest
@testable import RecallNative

final class ReviewMetricsActiveStreakTests: XCTestCase {
    func testActiveStreakUsesTodayWhenThereIsAReviewToday() {
        let calendar = fixedCalendar()
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_756_761_600))
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let reviews = [
            review(on: yesterday, rating: 3),
            review(on: today, rating: 4)
        ]

        let metrics = ReviewMetrics(reviews: reviews, calendar: calendar)

        XCTAssertEqual(metrics.activeStreak(endingOn: today), 2)
    }

    func testActiveStreakKeepsYesterdayStreakAtRiskToday() {
        let calendar = fixedCalendar()
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_756_761_600))
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let reviews = [
            review(on: twoDaysAgo, rating: 3),
            review(on: yesterday, rating: 4)
        ]

        let metrics = ReviewMetrics(reviews: reviews, calendar: calendar)

        XCTAssertEqual(metrics.streak(endingOn: today), 0)
        XCTAssertEqual(metrics.activeStreak(endingOn: today), 2)
    }

    func testActiveStreakIsZeroAfterMissingMoreThanOneDay() {
        let calendar = fixedCalendar()
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_756_761_600))
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let metrics = ReviewMetrics(reviews: [review(on: twoDaysAgo, rating: 3)], calendar: calendar)

        XCTAssertEqual(metrics.activeStreak(endingOn: today), 0)
    }

    private func review(on date: Date, rating: Int) -> ReviewLog {
        let review = ReviewLog(rating: rating)
        review.reviewedAt = date
        return review
    }

    private func fixedCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
