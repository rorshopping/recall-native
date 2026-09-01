import SwiftUI
import SwiftData

@main
struct RecallNativeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Deck.self, Flashcard.self, ReviewLog.self])
    }
}
