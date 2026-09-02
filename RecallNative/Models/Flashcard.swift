import Foundation
import SwiftData

@Model
final class Flashcard {
    var id: UUID
    var question: String
    var answer: String
    var hint: String
    var tags: String
    var type: String
    var typeInAnswer: Bool
    var mediaType: String?
    var mediaURI: String?
    var createdAt: Date
    var dueAt: Date
    var interval: Int
    var ease: Double
    var repetitions: Int
    var state: String
    var step: Int
    var lapses: Int
    var againCount: Int
    var hardCount: Int
    var goodCount: Int
    var easyCount: Int
    var lastReviewedAt: Date?
    var deck: Deck?

    convenience init(question: String, answer: String, deck: Deck? = nil) {
        self.init(question: question, answer: answer, hint: "", tags: "", deck: deck)
    }

    init(question: String, answer: String, hint: String?, tags: String?, deck: Deck? = nil) {
        self.id = UUID()
        self.question = question
        self.answer = answer
        self.hint = hint ?? ""
        self.tags = tags ?? ""
        self.type = "basic"
        self.typeInAnswer = false
        self.mediaType = nil
        self.mediaURI = nil
        self.createdAt = .now
        self.dueAt = .now
        self.interval = 0
        self.ease = 2.5
        self.repetitions = 0
        self.state = "new"
        self.step = 0
        self.lapses = 0
        self.againCount = 0
        self.hardCount = 0
        self.goodCount = 0
        self.easyCount = 0
        self.lastReviewedAt = nil
        self.deck = deck
    }

    var isNew: Bool { state == "new" }
    var isDue: Bool { dueAt <= .now }

    var statusTitle: String {
        switch state {
        case "new":
            return "New"
        case "learning":
            return isDue ? "Learning now" : "Learning · \(dueAt.formatted(date: .abbreviated, time: .shortened))"
        case "relearning":
            return isDue ? "Relearning now" : "Relearning · \(dueAt.formatted(date: .abbreviated, time: .shortened))"
        default:
            if dueAt <= .now { return "Due now" }
            return "Due \(dueAt.formatted(date: .abbreviated, time: .omitted))"
        }
    }
}
