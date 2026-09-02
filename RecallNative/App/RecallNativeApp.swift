import SwiftUI
import SwiftData
import UIKit

final class RecallNativeAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        guard identifier == BackgroundModelDownloader.sessionIdentifier else { return }
        BackgroundModelDownloader.shared.handleBackgroundEvents(completionHandler: completionHandler)
    }
}

@main
struct RecallNativeApp: App {
    @UIApplicationDelegateAdaptor(RecallNativeAppDelegate.self) private var appDelegate
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
