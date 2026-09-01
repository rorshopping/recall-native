import Foundation
import SwiftData

@Model
final class Flashcard {
    var id: UUID
    var question: String
    var answer: String
    var hint: String
    var tags: String
    var cardType: String
    var typeInAnswer: Bool
    var mediaType: String?
    var mediaURL: String?
    var createdAt: Date
    var dueAt: Date
    var interval: Int
    var ease: Double
    var repetitions: Int
    var state: String
    var step: Int
    var lapses: Int
    var lastReviewedAt: Date?
    var deck: Deck?

    init(question: String, answer: String, deck: Deck? = nil, hint: String = "", tags: String = "", cardType: String = "basic", typeInAnswer: Bool = false, mediaType: String? = nil, mediaURL: String? = nil) {
        self.id = UUID()
        self.question = question
        self.answer = answer
        self.hint = hint
        self.tags = tags
        self.cardType = cardType
        self.typeInAnswer = typeInAnswer
        self.mediaType = mediaType
        self.mediaURL = mediaURL
        self.createdAt = .now
        self.dueAt = .now
        self.interval = 0
        self.ease = 2.5
        self.repetitions = 0
        self.state = "new"
        self.step = 0
        self.lapses = 0
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

    func clozeText(revealed: Bool) -> String {
        guard cardType == "cloze" else { return revealed ? answer : question }
        let pattern = try? NSRegularExpression(pattern: "\\{\\{c\\d+::([^}]*)\\}\\}")
        let range = NSRange(question.startIndex..., in: question)
        return pattern?.stringByReplacingMatches(in: question, range: range, withTemplate: revealed ? "$1" : "… … …") ?? question
    }
}
