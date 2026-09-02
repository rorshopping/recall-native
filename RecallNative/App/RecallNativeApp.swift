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

@main
struct RecallNativeApp: App {
    @UIApplicationDelegateAdaptor(RecallNativeAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Deck.self, Flashcard.self, ReviewLog.self])
    }
}
