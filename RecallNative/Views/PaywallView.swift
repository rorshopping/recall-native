import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptions = SubscriptionService()
    let reason: String

    private let perks = [
        "Unlimited decks & cards",
        "All study modes & spaced repetition",
        "iCloud sync across your devices",
        "Yearly subscription, cancel anytime",
        "No ads, no account required"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(RecallTheme.accent)
                            .frame(width: 72, height: 72)
                            .background(RecallTheme.accent.opacity(0.12), in: Circle())
                        Text("Unlock Recall Full")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                        Text("Study without limits")
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 14) {
                        if let product = subscriptions.products.first {
                            Text(product.displayPrice)
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                            Text("per year · \(reason == "cards" ? "unlimited cards" : "unlimited decks & cards")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("39,99 €")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                            Text("per year · auto-renewable")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 15) {
                        ForEach(perks, id: \.self) { perk in
                            Label(perk, systemImage: "checkmark.circle.fill")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(RecallTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    if subscriptions.isPremium {
                        Label("Recall Full is active", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(RecallTheme.accent)
                            .font(.headline)
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                    } else if let product = subscriptions.products.first {
                        Button {
                            Task { await subscriptions.purchase(product) }
                        } label: {
                            HStack { Spacer(); Text("Subscribe · \(product.displayPrice) / year"); Spacer() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else {
                        ProgressView("Loading App Store offer…")
                    }

                    Button("Restore Purchase") { Task { await subscriptions.restore() } }
                        .buttonStyle(.bordered)

                    if let error = subscriptions.purchaseError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Text("Auto-renewable yearly subscription. Payment is charged to your Apple ID at confirmation. Renewal occurs unless auto-renew is turned off at least 24 hours before the end of the current period. Manage or cancel in App Store subscriptions.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
            .background(RecallTheme.canvas.ignoresSafeArea())
            .navigationTitle("Recall Full")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } }
            }
            .task { await subscriptions.load() }
        }
    }
}
