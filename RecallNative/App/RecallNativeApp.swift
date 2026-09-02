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
        if #available(iOS 26.0, *) {
            AIImportBackgroundTask.shared.register()
        }

        do {
            if decks.isEmpty {
                try SeedDataService.insertSampleDeck(into: modelContext)
            } else {
                try SeedDataService.migrateLegacySampleDeckIfNeeded(context: modelContext)
            }
        } catch {
            assertionFailure("Failed to bootstrap Recall data: \(error)")
        }

        // Resume any AI inbox work restored from the previous launch. This
        // happens independently of the inbox UI, so queued imports do not
        // require the user to reopen that screen.
        Task {
            await AIImportQueue.shared.startIfNeeded()
            if #available(iOS 26.0, *) {
                AIImportBackgroundTask.shared.submitIfNeeded()
            }
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
