import SwiftUI

struct SettingsView: View {
    @StateObject private var subscriptions = SubscriptionService()
    var body: some View {
        NavigationStack {
            Form {
                Section("Learning") {
                    Label("Spaced repetition", systemImage: "brain.head.profile")
                    Label("Daily goal", systemImage: "target")
                }
                Section("Account") {
                    if subscriptions.isPremium { Label("Premium active", systemImage: "checkmark.seal.fill") }
                    else { Text("Premium") }
                }
                Section("About") {
                    Label("Built natively with SwiftUI", systemImage: "swift")
                }
            }
            .navigationTitle("Settings")
            .task { await subscriptions.load() }
        }
    }
}
