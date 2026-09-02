import XCTest
@testable import RecallNative

final class ReviewSessionStateTests: XCTestCase {
    func testRemainingAndCompletionState() {
        var session = ReviewSessionState(total: 3)

        XCTAssertEqual(session.remaining, 3)
        XCTAssertFalse(session.isComplete)

        session.recordReview(completedCard: true, rating: 3)
        XCTAssertEqual(session.remaining, 2)
        XCTAssertFalse(session.isComplete)

        session.recordReview(completedCard: true, rating: 4)
        session.recordReview(completedCard: true, rating: 3)

        XCTAssertEqual(session.remaining, 0)
        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(session.progress, 3)
    }

    func testAgainDoesNotConsumeRemainingCard() {
        var session = ReviewSessionState(total: 2)

        session.recordReview(completedCard: false, rating: 1)

        XCTAssertEqual(session.reviewed, 1)
        XCTAssertEqual(session.progress, 0)
        XCTAssertEqual(session.remaining, 2)
        XCTAssertFalse(session.isComplete)
    }

    func testEmptySessionIsNotMarkedComplete() {
        let session = ReviewSessionState(total: 0)

        XCTAssertEqual(session.remaining, 0)
        XCTAssertFalse(session.isComplete)
        XCTAssertEqual(session.completionRate, 0)
    }

    func testResetRestoresRemainingState() {
        var session = ReviewSessionState(total: 2)
        session.recordReview(completedCard: true, rating: 4)
        session.reset(total: 5)

        XCTAssertEqual(session.total, 5)
        XCTAssertEqual(session.remaining, 5)
        XCTAssertFalse(session.isComplete)
        XCTAssertEqual(session.reviewed, 0)
    }

    func testRatingCountsAndPositiveRate() {
        var session = ReviewSessionState(total: 4)

        session.recordReview(completedCard: false, rating: 1)
        session.recordReview(completedCard: false, rating: 2)
        session.recordReview(completedCard: true, rating: 3)
        session.recordReview(completedCard: true, rating: 4)

        XCTAssertEqual(session.ratingCount(1), 1)
        XCTAssertEqual(session.ratingCount(2), 1)
        XCTAssertEqual(session.ratingCount(3), 1)
        XCTAssertEqual(session.ratingCount(4), 1)
        XCTAssertEqual(session.positiveRate, 50)
        XCTAssertEqual(session.completionRate, 50)
    }

    func testInvalidRatingsDoNotPolluteSessionMetrics() {
        var session = ReviewSessionState(total: 1)

        session.recordReview(completedCard: false, rating: 0)
        session.recordReview(completedCard: false, rating: 5)
        session.recordReview(completedCard: true, rating: nil)

        XCTAssertEqual(session.reviewed, 3)
        XCTAssertEqual(session.ratingCount(0), 0)
        XCTAssertEqual(session.ratingCount(5), 0)
        XCTAssertEqual(session.positiveRate, 0)
        XCTAssertEqual(session.completionRate, 100)
    }
}
