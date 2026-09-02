import SwiftUI
import SwiftData

@main
struct RecallNativeApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                RootView()
            } else {
                OnboardingView()
            }
        }
        .modelContainer(for: [Deck.self, Flashcard.self, ReviewLog.self])
    }
}
