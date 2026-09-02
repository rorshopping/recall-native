import Foundation
import SwiftData
import Testing
@testable import RecallNative

struct BackupServiceTests {
    @Test @MainActor
    func importsOriginalRecallNestedBackup() throws {
        let schema = Schema([Deck.self, Flashcard.self, ReviewLog.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let deckID = UUID()
        let cardID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let due = Date(timeIntervalSince1970: 1_700_086_400)

        let json: [String: Any] = [
            "schemaVersion": 2,
            "decks": [[
                "id": deckID.uuidString,
                "name": "Imported Spanish",
                "createdAt": createdAt.timeIntervalSince1970 * 1000,
                "newLimit": 15,
                "newDay": "Mon Sep 01 2026",
                "newStudiedToday": 3,
                "cards": [[
                    "id": cardID.uuidString,
                    "front": "Hola",
                    "back": "Hello",
                    "hint": "Greeting",
                    "tags": "spanish,basics",
                    "type": "basic",
                    "typeIn": true,
                    "media": ["type": "image", "uri": "file:///tmp/hello.jpg"],
                    "ease": 2.7,
                    "interval": 4,
                    "reps": 3,
                    "lapses": 1,
                    "due": due.timeIntervalSince1970 * 1000,
                    "lastReviewed": createdAt.timeIntervalSince1970 * 1000,
                    "state": "review",
                    "step": 0,
                    "stats": ["again": 1, "hard": 2, "good": 3, "easy": 4],
                    "createdAt": createdAt.timeIntervalSince1970 * 1000
                ]
            ]],
            "meta": [
                "streak": 4,
                "lastStudyDate": "Mon Sep 01 2026",
                "studiedToday": 3,
                "totalReviewed": 10,
                "totalCreated": 1,
                "entitlement": ["full": true],
                "iCloudEnabled": false,
                "history": ["Mon Sep 01 2026": 3],
                "hapticsEnabled": true
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        try BackupService.restoreAny(data, context: context, replaceExisting: true)

        let decks = try context.fetch(FetchDescriptor<Deck>())
        let cards = try context.fetch(FetchDescriptor<Flashcard>())
        #expect(decks.count == 1)
        #expect(cards.count == 1)
        #expect(decks[0].id == deckID)
        #expect(decks[0].name == "Imported Spanish")
        #expect(decks[0].newLimit == 15)
        #expect(decks[0].newStudiedToday == 3)
        #expect(cards[0].id == cardID)
        #expect(cards[0].question == "Hola")
        #expect(cards[0].answer == "Hello")
        #expect(cards[0].typeInAnswer)
        #expect(cards[0].mediaType == "image")
        #expect(cards[0].mediaURI == "file:///tmp/hello.jpg")
        #expect(cards[0].interval == 4)
        #expect(cards[0].ease == 2.7)
        #expect(cards[0].repetitions == 3)
        #expect(cards[0].lapses == 1)
        #expect(cards[0].againCount == 1)
        #expect(cards[0].hardCount == 2)
        #expect(cards[0].goodCount == 3)
        #expect(cards[0].easyCount == 4)
    }
}
