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
}
