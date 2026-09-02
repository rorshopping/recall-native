import SwiftUI
import SwiftData
import UIKit

final class RecallNativeAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        guard identifier == BackgroundModelDownloader.sessionIdentifier else {
            completionHandler()
            return
        }
        BackgroundModelDownloader.shared.handleBackgroundEvents(completionHandler: completionHandler)
    }
}

private struct RecallBootstrapView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var decks: [Deck]
    @State private var didAttemptSeed = false

    var body: some View {
        RootView()
            .task {
                guard !didAttemptSeed else { return }
                didAttemptSeed = true
                seedFreshStoreIfNeeded()
            }
    }

    @MainActor
    private func seedFreshStoreIfNeeded() {
        guard decks.isEmpty else { return }

        do {
            try SeedDataService.insertSampleDeck(into: modelContext)
        } catch {
            assertionFailure("Failed to seed the sample deck: \(error)")
        }
    }
}

@main
struct RecallNativeApp: App {
    @UIApplicationDelegateAdaptor(RecallNativeAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RecallBootstrapView()
        }
        .modelContainer(for: [Deck.self, Flashcard.self, ReviewLog.self])
    }
}
