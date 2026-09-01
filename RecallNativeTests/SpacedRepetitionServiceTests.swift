import XCTest
@testable import RecallNative

final class SpacedRepetitionServiceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testNewGoodMovesToSecondLearningStep() {
        let result = SpacedRepetitionService.schedule(state: "new", step: 0, repetitions: 0, interval: 0, ease: 2.5, grade: 2, now: now)
        XCTAssertEqual(result.state, "learning")
        XCTAssertEqual(result.step, 1)
        XCTAssertEqual(result.repetitions, 0)
        XCTAssertEqual(result.interval, 0)
        XCTAssertEqual(result.dueAt.timeIntervalSince(now), 600, accuracy: 0.001)
    }

    func testLearningGoodOnFinalStepGraduates() {
        let result = SpacedRepetitionService.schedule(state: "learning", step: 1, repetitions: 0, interval: 0, ease: 2.5, grade: 2, now: now)
        XCTAssertEqual(result.state, "review")
        XCTAssertEqual(result.step, 0)
        XCTAssertEqual(result.repetitions, 1)
        XCTAssertEqual(result.interval, 1)
        XCTAssertEqual(result.ease, 2.6, accuracy: 0.0001)
    }

    func testEasyGraduatesImmediately() {
        let result = SpacedRepetitionService.schedule(state: "new", step: 0, repetitions: 0, interval: 0, ease: 2.5, grade: 3, now: now)
        XCTAssertEqual(result.state, "review")
        XCTAssertEqual(result.interval, 1)
        XCTAssertEqual(result.repetitions, 1)
        XCTAssertEqual(result.ease, 2.65, accuracy: 0.0001)
    }

    func testAgainFromReviewEntersRelearning() {
        let result = SpacedRepetitionService.schedule(state: "review", step: 0, repetitions: 4, interval: 20, ease: 2.5, grade: 0, now: now)
        XCTAssertEqual(result.state, "relearning")
        XCTAssertEqual(result.step, 0)
        XCTAssertEqual(result.repetitions, 0)
        XCTAssertEqual(result.interval, 0)
        XCTAssertEqual(result.ease, 2.3, accuracy: 0.0001)
        XCTAssertEqual(result.dueAt.timeIntervalSince(now), 60, accuracy: 0.001)
    }

    func testReviewIntervalsMatchRecall() {
        let hard = SpacedRepetitionService.schedule(state: "review", step: 0, repetitions: 2, interval: 6, ease: 2.5, grade: 1, now: now)
        XCTAssertEqual(hard.interval, 7)
        XCTAssertEqual(hard.ease, 2.5, accuracy: 0.0001)

        let good = SpacedRepetitionService.schedule(state: "review", step: 0, repetitions: 2, interval: 6, ease: 2.5, grade: 2, now: now)
        XCTAssertEqual(good.interval, 15)
        XCTAssertEqual(good.ease, 2.6, accuracy: 0.0001)

        let easy = SpacedRepetitionService.schedule(state: "review", step: 0, repetitions: 2, interval: 6, ease: 2.5, grade: 3, now: now)
        XCTAssertEqual(easy.interval, 20)
        XCTAssertEqual(easy.ease, 2.65, accuracy: 0.0001)
    }
}
