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

        let deck = Deck(name: "Spanish Basics — Sample")
        let cards: [(String, String, String, String)] = [
            ("How do you say 'apple'?", "manzana", "la fruta roja", "food"),
            ("How do you say 'house'?", "casa", "", "food"),
            ("How do you say 'thank you'?", "gracias", "", "phrases"),
            ("How do you say 'water'?", "agua", "la bebida", "food"),
            ("Conjugate: yo (to eat)", "como", "infinitive: comer", "verbs"),
            ("What is 'el perro'?", "the dog", "", "animals")
        ]

        for (question, answer, hint, tags) in cards {
            deck.cards.append(Flashcard(question: question, answer: answer, hint: hint, tags: tags, deck: deck))
        }

        modelContext.insert(deck)
        do {
            try modelContext.save()
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
