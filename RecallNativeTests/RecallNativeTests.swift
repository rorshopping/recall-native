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

    @Test func learningAndRelearningCardsAreNotNew() {
        let learning = Flashcard(question: "Q", answer: "A")
        learning.state = "learning"
        #expect(!learning.isNew)

        let relearning = Flashcard(question: "Q", answer: "A")
        relearning.state = "relearning"
        #expect(!relearning.isNew)
    }

    @Test func flashcardStatusTitlesReflectLearningState() {
        let newCard = Flashcard(question: "Q", answer: "A")
        #expect(newCard.statusTitle == "New")

        let learning = Flashcard(question: "Q", answer: "A")
        learning.state = "learning"
        learning.dueAt = .now
        #expect(learning.statusTitle == "Learning now")

        let relearning = Flashcard(question: "Q", answer: "A")
        relearning.state = "relearning"
        relearning.dueAt = .now
        #expect(relearning.statusTitle == "Relearning now")

        let dueReview = Flashcard(question: "Q", answer: "A")
        dueReview.state = "review"
        dueReview.dueAt = .now
        #expect(dueReview.statusTitle == "Due now")
    }

    @Test func deckDailyNewCardCounterRollsOverByCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayOne = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let dayTwo = calendar.date(byAdding: .day, value: 1, to: dayOne)!
        let deck = Deck(name: "Test")

        deck.recordNewCardStudy(on: dayOne.addingTimeInterval(3_600), calendar: calendar)
        deck.recordNewCardStudy(on: dayOne.addingTimeInterval(7_200), calendar: calendar)
        #expect(deck.newStudiedToday == 2)

        deck.recordNewCardStudy(on: dayTwo.addingTimeInterval(3_600), calendar: calendar)
        #expect(deck.newStudiedToday == 1)
        #expect(deck.newDay != nil)
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

    @Test func reviewSessionStartsWithZeroProgress() {
        let session = ReviewSessionState(total: 5)
        #expect(session.total == 5)
        #expect(session.reviewed == 0)
        #expect(session.completed == 0)
        #expect(session.progress == 0)
        #expect(session.progressFraction == 0)
        #expect(session.ratingCounts.isEmpty)
        #expect(session.positiveRate == 0)
        #expect(session.completionRate == 0)
    }

    @Test func reviewSessionCountsCompletedCards() {
        var session = ReviewSessionState(total: 3)
        session.recordReview(completedCard: true, rating: 3)
        #expect(session.reviewed == 1)
        #expect(session.completed == 1)
        #expect(session.progress == 1)
        #expect(session.ratingCounts[3] == 1)
        #expect(session.ratingCount(3) == 1)
        #expect(session.positiveRate == 100)
        #expect(session.completionRate == 33)

        session.recordReview(completedCard: false, rating: 1)
        #expect(session.reviewed == 2)
        #expect(session.completed == 1)
        #expect(session.progress == 1)
        #expect(session.ratingCounts[1] == 1)
        #expect(session.ratingCount(1) == 1)
        #expect(session.positiveRate == 50)
    }

    @Test func reviewSessionAgainDoesNotAdvanceProgress() {
        var session = ReviewSessionState(total: 2)
        session.recordReview(completedCard: false, rating: 1)
        #expect(session.reviewed == 1)
        #expect(session.completed == 0)
        #expect(session.progress == 0)
        #expect(session.progressFraction == 0)
        #expect(session.ratingCounts[1] == 1)

        session.recordReview(completedCard: true, rating: 4)
        #expect(session.progress == 1)
        #expect(session.ratingCounts[4] == 1)
        #expect(session.ratingCount(4) == 1)
        #expect(session.positiveRate == 50)
        #expect(session.completionRate == 50)
    }

    @Test func reviewSessionIgnoresInvalidRating() {
        var session = ReviewSessionState(total: 1)
        session.recordReview(completedCard: true, rating: 0)
        session.recordReview(completedCard: true, rating: 5)
        #expect(session.reviewed == 2)
        #expect(session.ratingCounts.isEmpty)
        #expect(session.positiveRate == 0)
    }

    @Test func reviewSessionResetClearsAccounting() {
        var session = ReviewSessionState(total: 2)
        session.recordReview(completedCard: true, rating: 2)
        session.reset(total: 7)
        #expect(session.total == 7)
        #expect(session.reviewed == 0)
        #expect(session.completed == 0)
        #expect(session.progress == 0)
        #expect(session.progressFraction == 0)
        #expect(session.ratingCounts.isEmpty)
        #expect(session.positiveRate == 0)
        #expect(session.completionRate == 0)
    }

    @Test func reviewMetricsCalculateRatingAverageAndPositiveRate() {
        let reviews = [1, 2, 3, 4].map { ReviewLog(rating: $0) }
        let metrics = ReviewMetrics(reviews: reviews)
        #expect(metrics.total == 4)
        #expect(metrics.averageRating == 2.5)
        #expect(metrics.ratingCounts[1] == 1)
        #expect(metrics.ratingCounts[4] == 1)
        #expect(metrics.positiveRate == 50)
    }

    @Test func reviewMetricsCalculateRatingPercentages() {
        let reviews = [1, 2, 2, 3, 4].map { ReviewLog(rating: $0) }
        let metrics = ReviewMetrics(reviews: reviews)
        #expect(metrics.ratingPercentage(1) == 20)
        #expect(metrics.ratingPercentage(2) == 40)
        #expect(metrics.ratingPercentage(3) == 20)
        #expect(metrics.ratingPercentage(4) == 20)
        #expect(metrics.ratingPercentage(9) == 0)
    }

    @Test func reviewMetricsCalculateRollingCountsAndStreak() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayOne = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let dayTwo = calendar.date(byAdding: .day, value: 1, to: dayOne)!
        let dayThree = calendar.date(byAdding: .day, value: 1, to: dayOne)!
        let dayFour = calendar.date(byAdding: .day, value: 1, to: dayOne)!

        let first = ReviewLog(rating: 3); first.reviewedAt = dayTwo.addingTimeInterval(3_600)
        let second = ReviewLog(rating: 4); second.reviewedAt = dayThree.addingTimeInterval(7_200)
        let third = ReviewLog(rating: 2); third.reviewedAt = dayFour.addingTimeInterval(10_800)
        let fourth = ReviewLog(rating: 1); fourth.reviewedAt = dayFour.addingTimeInterval(14_400)
        let metrics = ReviewMetrics(reviews: [first, second, third, fourth], calendar: calendar)

        #expect(metrics.count(inLastDays: 1, endingOn: dayFour) == 2)
        #expect(metrics.count(inLastDays: 2, endingOn: dayFour) == 3)
        #expect(metrics.count(inLastDays: 4, endingOn: dayFour) == 4)
        #expect(metrics.count(inLastDays: 0, endingOn: dayFour) == 0)
        #expect(metrics.streak(endingOn: dayFour) == 3)
        #expect(metrics.streak(endingOn: dayOne) == 0)
    }

    @Test func reviewMetricsCountInclusiveDateRange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let middle = calendar.date(byAdding: .day, value: 1, to: start)!
        let end = calendar.date(byAdding: .day, value: 2, to: start)!
        let outside = calendar.date(byAdding: .day, value: 3, to: start)!

        let first = ReviewLog(rating: 3); first.reviewedAt = start.addingTimeInterval(3_600)
        let second = ReviewLog(rating: 4); second.reviewedAt = middle.addingTimeInterval(7_200)
        let third = ReviewLog(rating: 2); third.reviewedAt = end.addingTimeInterval(10_800)
        let fourth = ReviewLog(rating: 1); fourth.reviewedAt = outside
        let metrics = ReviewMetrics(reviews: [first, second, third, fourth], calendar: calendar)

        #expect(metrics.count(on: start) == 1)
        #expect(metrics.count(on: middle) == 1)
        #expect(metrics.count(from: start, through: end) == 3)
        #expect(metrics.count(from: end, through: start) == 0)
    }

    @Test func reviewMetricsReturnZeroForEmptyReviews() {
        let metrics = ReviewMetrics(reviews: [])
        #expect(metrics.total == 0)
        #expect(metrics.averageRating == 0)
        #expect(metrics.positiveRate == 0)
        #expect(metrics.ratingPercentage(4) == 0)
        #expect(metrics.count(inLastDays: 7) == 0)
        #expect(metrics.streak() == 0)
        #expect(metrics.count(from: .now, through: .now) == 0)
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

    @Test func iCloudSyncEnvelopeRoundTrips() throws {
        let timestamp = Date(timeIntervalSince1970: 1_234_567)
        let envelope = ICloudSyncService.SyncEnvelope(
            schemaVersion: ICloudSyncService.SyncEnvelope.currentSchemaVersion,
            deviceID: "device-test",
            updatedAt: timestamp,
            backupData: Data("backup".utf8)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(envelope)
        let decoded = try decoder.decode(ICloudSyncService.SyncEnvelope.self, from: data)
        #expect(decoded == envelope)
    }

    @Test func iCloudSyncEnvelopeUsesCurrentSchema() {
        #expect(ICloudSyncService.SyncEnvelope.currentSchemaVersion == 1)
    }
}

private extension JSONEncoder {
    static var iso8601: JSONEncoder { let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; return encoder }
}
