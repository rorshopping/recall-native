import Foundation
import SwiftData
import Testing
@testable import RecallNative

struct BackupCompatibilityTests {
    @Test func legacyV1BackupWithoutDeckLimitDefaultsToTwenty() throws {
        let deckID = UUID()
        let json = """
        {
          "cards": [],
          "decks": [{
            "createdAt": "2026-09-02T00:00:00Z",
            "emoji": "📚",
            "id": "\(deckID.uuidString)",
            "name": "Legacy",
            "newDay": "",
            "newStudiedToday": 0
          }],
          "exportedAt": "2026-09-02T00:00:00Z",
          "reviews": [],
          "version": 1
        }
        """

        let backup = try BackupService.validate(Data(json.utf8))
        #expect(backup.decks.count == 1)
        #expect(backup.decks[0].id == deckID)
        #expect(backup.decks[0].newLimit == 20)
    }

    @Test func originalRecallBackupPreservesHapticPreference() throws {
        let deckID = UUID()
        let json = """
        {
          "schemaVersion": 3,
          "decks": [{
            "id": "\(deckID.uuidString)",
            "name": "Spanish Basics",
            "createdAt": 1756771200000,
            "newLimit": 20,
            "newDay": "2026-09-02",
            "newStudiedToday": 0,
            "cards": []
          }],
          "meta": {
            "streak": 2,
            "lastStudyDate": "2026-09-01",
            "studiedToday": 0,
            "totalReviewed": 4,
            "totalCreated": 0,
            "entitlement": {"full": false},
            "iCloudEnabled": false,
            "history": {"2026-09-01": 4},
            "hapticsEnabled": false
          }
        }
        """

        let backup = try BackupService.validate(Data(json.utf8))
        #expect(backup.decks.count == 1)
        #expect(backup.decks[0].id == deckID)
        try BackupService.restore(Data(json.utf8), context: makeContext(), replaceExisting: true)
        #expect(UserDefaults.standard.bool(forKey: "hapticsEnabled") == false)
    }

    @Test @MainActor func nativeBackupRoundTripsHapticPreference() throws {
        let key = "hapticsEnabled"
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous { UserDefaults.standard.set(previous, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        UserDefaults.standard.set(false, forKey: key)

        let context = makeContext()
        let deck = Deck(name: "Preference test")
        context.insert(deck)
        try context.save()

        let data = try BackupService.makeBackup(context: context)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(object?["hapticsEnabled"] as? Bool == false)
    }

    private func makeContext() -> ModelContext {
        let schema = Schema([Deck.self, Flashcard.self, ReviewLog.self])
        let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }
}
