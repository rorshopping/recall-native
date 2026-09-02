import Foundation
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
}
