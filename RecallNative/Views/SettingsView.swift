import SwiftUI
import StoreKit

struct SettingsView: View {
    @StateObject private var subscriptions = SubscriptionService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Learning") {
                    Label("Spaced repetition", systemImage: "brain.head.profile")
                    Label("Daily goal", systemImage: "target")
                }

                Section("Premium") {
                    if subscriptions.isPremium {
                        Label("Premium active", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(RecallTheme.accent)
                    } else if subscriptions.products.isEmpty {
                        Text("Premium options will appear here when App Store products are configured.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(subscriptions.products) { product in
                            Button {
                                Task { await subscriptions.purchase(product) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(product.displayName)
                                        Text(product.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Text(product.displayPrice).font(.headline)
                                }
                            }
                        }
                    }

                    Button("Restore Purchases") {
                        Task { await subscriptions.restore() }
                    }
                }

                Section("About") {
                    Label("Built natively with SwiftUI", systemImage: "swift")
                    Text("Recall Native").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .task { await subscriptions.load() }
            .alert("Purchase issue", isPresented: Binding(get: { subscriptions.purchaseError != nil }, set: { if !$0 { subscriptions.clearError() } })) {
                Button("OK") { subscriptions.clearError() }
            } message: {
                Text(subscriptions.purchaseError ?? "")
            }
        }
    }
}
