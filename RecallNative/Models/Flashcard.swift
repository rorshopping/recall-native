import Foundation
import SwiftData

@Model
final class Flashcard {
    var id: UUID
    var question: String
    var answer: String
    var createdAt: Date
    var dueAt: Date
    var interval: Int
    var ease: Double
    var repetitions: Int
    var deck: Deck?

    init(question: String, answer: String, deck: Deck? = nil) {
        self.id = UUID()
        self.question = question
        self.answer = answer
        self.createdAt = .now
        self.dueAt = .now
        self.interval = 0
        self.ease = 2.5
        self.repetitions = 0
        self.deck = deck
    }

    var isNew: Bool { repetitions == 0 }
    var isDue: Bool { dueAt <= .now }
    var statusTitle: String {
        if isNew { return "New" }
        if dueAt <= .now { return "Due now" }
        return "Due \(dueAt.formatted(date: .abbreviated, time: .omitted))"
    }
}
