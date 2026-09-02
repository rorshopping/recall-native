import Foundation
import Testing
@testable import RecallNative

struct DeckDailyAccountingTests {
    @Test func dailyNewRemainingUsesRecordedIntroductions() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayOne = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let dayTwo = calendar.date(byAdding: .day, value: 1, to: dayOne)!
        let deck = Deck(name: "Daily limit")
        deck.newLimit = 2

        let first = Flashcard(question: "1", answer: "A")
        let second = Flashcard(question: "2", answer: "B")
        let third = Flashcard(question: "3", answer: "C")
        deck.cards = [first, second, third]

        #expect(deck.newRemainingToday == 2)
        deck.recordNewCardStudy(on: dayOne.addingTimeInterval(3_600), calendar: calendar)
        #expect(deck.newStudiedToday == 1)
        #expect(deck.newRemainingToday == 1)

        deck.recordNewCardStudy(on: dayOne.addingTimeInterval(7_200), calendar: calendar)
        #expect(deck.newStudiedToday == 2)
        #expect(deck.newRemainingToday == 0)

        deck.recordNewCardStudy(on: dayTwo.addingTimeInterval(3_600), calendar: calendar)
        #expect(deck.newStudiedToday == 1)
        #expect(deck.newRemainingToday == 1)
    }

    @Test func dailyNewRemainingNeverExceedsAvailableNewCards() {
        let deck = Deck(name: "Small deck")
        deck.newLimit = 20
        deck.cards = [Flashcard(question: "Q", answer: "A")]

        deck.recordNewCardStudy()
        #expect(deck.newRemainingToday == 0)
    }

    @Test func recordingPastDailyLimitDoesNotIncreaseUsage() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 2))!
        let deck = Deck(name: "Capped deck")
        deck.newLimit = 2
        deck.cards = [
            Flashcard(question: "1", answer: "A"),
            Flashcard(question: "2", answer: "B"),
            Flashcard(question: "3", answer: "C")
        ]

        deck.recordNewCardStudy(on: day, calendar: calendar)
        deck.recordNewCardStudy(on: day.addingTimeInterval(60), calendar: calendar)
        deck.recordNewCardStudy(on: day.addingTimeInterval(120), calendar: calendar)

        #expect(deck.newStudiedToday == 2)
        #expect(deck.newRemainingToday == 0)
    }
}
