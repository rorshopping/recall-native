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
    @State private var didAttemptBootstrap = false

    var body: some View {
        RootView()
            .task {
                guard !didAttemptBootstrap else { return }
                didAttemptBootstrap = true
                bootstrapStore()
            }
    }

    @MainActor
    private func bootstrapStore() {
        do {
            if decks.isEmpty {
                try SeedDataService.insertSampleDeck(into: modelContext)
            } else {
                try SeedDataService.migrateLegacySampleDeckIfNeeded(context: modelContext)
            }
        } catch {
            assertionFailure("Failed to bootstrap Recall data: \(error)")
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
