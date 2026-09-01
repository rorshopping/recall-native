import Foundation
import SwiftData
import Testing
@testable import RecallNative

struct RecallNativeTests {
    @Test func newCardGoodGraduatesToReview() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let result = SpacedRepetitionService.schedule(state: "new", step: 1, repetitions: 0, interval: 0, ease: 2.5, grade: 2, now: now)
        #expect(result.state == "review")
        #expect(result.repetitions == 1)
        #expect(result.interval == 1)
        #expect(result.dueAt == now.addingTimeInterval(86_400))
    }

    @Test func hardLearningAdvancesToNextLearningStep() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let result = SpacedRepetitionService.schedule(state: "learning", step: 0, repetitions: 0, interval: 0, ease: 2.5, grade: 1, now: now)
        #expect(result.state == "learning")
        #expect(result.step == 0)
        #expect(result.dueAt == now.addingTimeInterval(60))
    }

    @Test func againOnReviewStartsRelearning() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let result = SpacedRepetitionService.schedule(state: "review", step: 0, repetitions: 4, interval: 12, ease: 2.5, grade: 0, now: now)
        #expect(result.state == "relearning")
        #expect(result.repetitions == 0)
        #expect(result.interval == 0)
        #expect(result.ease == 2.3)
        #expect(result.dueAt == now.addingTimeInterval(60))
    }

    @Test func easyReviewIncreasesIntervalAndEase() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let result = SpacedRepetitionService.schedule(state: "review", step: 0, repetitions: 2, interval: 6, ease: 2.5, grade: 3, now: now)
        #expect(result.state == "review")
        #expect(result.repetitions == 3)
        #expect(result.interval == 20)
        #expect(result.ease == 2.65)
        #expect(result.dueAt == now.addingTimeInterval(20 * 86_400))
    }

    @Test func flashcardDefaultsToNewAndDueNow() {
        let card = Flashcard(question: "Q", answer: "A")
        #expect(card.isNew)
        #expect(card.isDue)
        #expect(card.type == "basic")
        #expect(card.typeInAnswer == false)
        #expect(card.interval == 0)
        #expect(card.ease == 2.5)
    }

    @Test func importedDeckPreservesCardMetadata() throws {
        let schema = Schema([Deck.self, Flashcard.self, ReviewLog.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let json = #"{"deck":"Biology","cards":[{"front":"Cell","back":"Basic unit of life","hint":"Think smallest living unit","tags":"biology,basics"}]}"#.data(using: .utf8)!
        let deck = try DeckImportService.add(json, to: context)
        #expect(deck.name == "Biology")
        #expect(deck.cards.count == 1)
        #expect(deck.cards.first?.hint == "Think smallest living unit")
        #expect(deck.cards.first?.tags == "biology,basics")
    }

    @Test func freeTierAllowsExactlyOneDeck() {
        #expect(EntitlementRules.canCreateDeck(isPremium: false, deckCount: 0))
        #expect(!EntitlementRules.canCreateDeck(isPremium: false, deckCount: 1))
        #expect(EntitlementRules.canCreateDeck(isPremium: true, deckCount: 100))
    }

    @Test func freeTierAllowsExactlyFiftyCardsPerDeck() {
        #expect(EntitlementRules.canCreateCard(isPremium: false, cardCount: 49))
        #expect(!EntitlementRules.canCreateCard(isPremium: false, cardCount: 50))
        #expect(EntitlementRules.canCreateCard(isPremium: true, cardCount: 500))
    }

    @Test func backupRejectsOrphanedCard() throws {
        let orphanDeck = UUID()
        let card = UUID()
        let backup = RecallBackup(version: 1, exportedAt: .now, decks: [], cards: [.init(id: card, question: "Q", answer: "A", hint: "", tags: "", type: "basic", typeInAnswer: false, mediaType: nil, mediaURI: nil, createdAt: .now, dueAt: .now, interval: 0, ease: 2.5, repetitions: 0, state: "new", step: 0, lapses: 0, againCount: 0, hardCount: 0, goodCount: 0, easyCount: 0, lastReviewedAt: nil, deckID: orphanDeck)], reviews: [])
        let data = try JSONEncoder.iso8601.encode(backup)
        #expect(throws: BackupService.BackupError.orphanedCards) { try BackupService.validate(data) }
    }

    @Test func backupRejectsDuplicateIDs() throws {
        let id = UUID()
        let deck = RecallBackup.DeckRecord(id: id, name: "A", emoji: "📚", createdAt: .now, newDay: "", newStudiedToday: 0)
        let backup = RecallBackup(version: 1, exportedAt: .now, decks: [deck, deck], cards: [], reviews: [])
        let data = try JSONEncoder.iso8601.encode(backup)
        #expect(throws: BackupService.BackupError.duplicateIDs) { try BackupService.validate(data) }
    }

    @Test func backupRejectsIDCollisionOnMergeRestore() throws {
        let schema = Schema([Deck.self, Flashcard.self, ReviewLog.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let id = UUID()
        let existing = Deck(name: "Existing")
        existing.id = id
        context.insert(existing)
        try context.save()
        let incoming = RecallBackup.DeckRecord(id: id, name: "Incoming", emoji: "📚", createdAt: .now, newDay: "", newStudiedToday: 0)
        let backup = RecallBackup(version: 1, exportedAt: .now, decks: [incoming], cards: [], reviews: [])
        let data = try JSONEncoder.iso8601.encode(backup)
        #expect(throws: BackupService.BackupError.idCollision) { try BackupService.restore(data, context: context, replaceExisting: false) }
    }
}

private extension JSONEncoder {
    static var iso8601: JSONEncoder { let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; return encoder }
}
