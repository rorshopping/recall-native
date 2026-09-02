import Foundation
import Testing
@testable import RecallNative

struct ReviewMetricsTests {
    @Test func emptyMetricsHaveZeroValues() {
        let metrics = ReviewMetrics(reviews: [])
        #expect(metrics.total == 0)
        #expect(metrics.positiveRate == 0)
        #expect(metrics.ratingCounts.isEmpty)
        #expect(metrics.count(on: .now) == 0)
    }

    @Test func ratingCountsAndPositiveRateAreCalculated() {
        let first = ReviewLog(rating: 1)
        let second = ReviewLog(rating: 2)
        let third = ReviewLog(rating: 3)
        let fourth = ReviewLog(rating: 4)
        let metrics = ReviewMetrics(reviews: [first, second, third, fourth])

        #expect(metrics.total == 4)
        #expect(metrics.ratingCounts[1] == 1)
        #expect(metrics.ratingCounts[2] == 1)
        #expect(metrics.ratingCounts[3] == 1)
        #expect(metrics.ratingCounts[4] == 1)
        #expect(metrics.positiveRate == 50)
    }

    @Test func dailyCountsUseCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 1_735_689_600)
        let sameDayLater = day.addingTimeInterval(3_600)
        let nextDay = day.addingTimeInterval(86_400)

        let first = ReviewLog(rating: 3)
        first.reviewedAt = day
        let second = ReviewLog(rating: 4)
        second.reviewedAt = sameDayLater
        let third = ReviewLog(rating: 2)
        third.reviewedAt = nextDay

        let metrics = ReviewMetrics(reviews: [first, second, third], calendar: calendar)

        #expect(metrics.count(on: day) == 2)
        #expect(metrics.count(on: nextDay) == 1)
        #expect(metrics.counts(for: [day, nextDay]) == [2, 1])
    }
}
