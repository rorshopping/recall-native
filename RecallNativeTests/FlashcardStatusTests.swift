import Foundation
import Testing
@testable import RecallNative

struct FlashcardStatusTests {
    @Test func newCardsShowNewStatus() {
        let card = Flashcard(question: "Q", answer: "A")
        #expect(card.statusTitle == "New")
    }

    @Test func dueLearningCardsShowLearningNow() {
        let card = Flashcard(question: "Q", answer: "A")
        card.state = "learning"
        card.dueAt = .now.addingTimeInterval(-1)
        #expect(card.statusTitle == "Learning now")
    }

    @Test func dueRelearningCardsShowRelearningNow() {
        let card = Flashcard(question: "Q", answer: "A")
        card.state = "relearning"
        card.dueAt = .now.addingTimeInterval(-1)
        #expect(card.statusTitle == "Relearning now")
    }

    @Test func scheduledCardsShowDueDate() {
        let card = Flashcard(question: "Q", answer: "A")
        card.state = "review"
        card.dueAt = .now.addingTimeInterval(86_400)
        #expect(card.statusTitle.hasPrefix("Due "))
    }
}
