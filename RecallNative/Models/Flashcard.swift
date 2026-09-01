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

    init(question: String, answer: String, deck: Deck? = nil) {
        self.id = UUID()
        self.question = question
        self.answer = answer
        self.hint = ""
        self.tags = ""
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

    var isNew: Bool { state == "new" || repetitions == 0 }
    var isDue: Bool { dueAt <= .now }
    var statusTitle: String {
        if isNew { return "New" }
        if dueAt <= .now { return "Due now" }
        return "Due \(dueAt.formatted(date: .abbreviated, time: .omitted))"
    }
}
