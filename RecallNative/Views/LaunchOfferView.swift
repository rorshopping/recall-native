import SwiftUI
import SwiftData
import StoreKit

struct LaunchOfferView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var decks: [Deck]
    @Query private var cards: [Flashcard]
    @Query private var reviews: [ReviewLog]
    @StateObject private var subscriptions = SubscriptionService()
    @AppStorage("recall.launchOffer.v1.dismissed") private var dismissed = false
    @State private var didLoad = false
    @State private var isPurchasing = false
    @State private var isRestoring = false

    private let priceFallback = "39,99 €"

    private var hasEarnedValue: Bool {
        let hasNonSampleDeck = decks.contains { deck in
            deck.name != "Spanish Basics" && deck.name != "Spanish Basics — Sample"
        }
        let hasMultipleDecks = decks.count > 1
        let hasEnoughCards = cards.count > 6
        let hasEnoughReviews = reviews.count >= 3
        let hasStudyHistory = !reviews.isEmpty || !ReviewHistoryStore.load().isEmpty
        let hasCreationHistory = UsageMetricsStore.totalCreated > 6
        return hasNonSampleDeck || hasMultipleDecks || hasEnoughCards || hasEnoughReviews || hasStudyHistory || hasCreationHistory
    }

    private var shouldShow: Bool {
        didLoad && !dismissed && !subscriptions.isPremium && hasEarnedValue
    }

    private var isBusy: Bool {
        isPurchasing || isRestoring
    }

    var body: some View {
        Group {
            if shouldShow { content }
        }
        .task {
            await subscriptions.load()
            didLoad = true
        }
        .onChange(of: subscriptions.isPremium) { _, premium in
            if premium {
                dismissed = true
                dismiss()
            }
        }
        .onDisappear {
            if !subscriptions.isPremium {
                dismissed = true
            }
        }
    }

    private var content: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        Button("Not now") {
                            dismissed = true
                            dismiss()
                        }
                        .foregroundStyle(.secondary)
                        .disabled(isBusy)
                    }
                    .frame(maxWidth: 520)

                    RecallCard {
                        VStack(spacing: 16) {
                            Text("YEARLY · \(subscriptions.products.first?.displayPrice ?? priceFallback)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(RecallTheme.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(RecallTheme.accent.opacity(0.12), in: Capsule())

                            Text("Recall Full").font(.title.bold())
                            Text(subscriptions.products.first?.displayPrice ?? priceFallback)
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(RecallTheme.accent)
                            Text("\(subscriptions.products.first?.displayPrice ?? priceFallback) / year · unlimited decks & cards")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 11) {
                                perk("Unlimited decks & cards")
                                perk("All study modes & spaced repetition")
                                perk("iCloud sync across your devices")
                                perk("Yearly subscription · cancel anytime")
                                perk("No ads, no account required")
                            }
                            .frame(maxWidth: 420, alignment: .leading)

                            if let product = subscriptions.products.first {
                                Button {
                                    guard !isBusy else { return }
                                    isPurchasing = true
                                    Task { @MainActor in
                                        await subscriptions.purchase(product)
                                        isPurchasing = false
                                    }
                                } label: {
                                    Group {
                                        if isPurchasing { ProgressView().tint(.white) }
                                        else { Text("Subscribe · \(product.displayPrice) / year") }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(RecallTheme.accent)
                                .disabled(isBusy)
                            }

                            Button {
                                guard !isBusy else { return }
                                isRestoring = true
                                Task { @MainActor in
                                    await subscriptions.restore()
                                    isRestoring = false
                                }
                            } label: {
                                Group {
                                    if isRestoring { ProgressView() }
                                    else { Text("Restore purchase") }
                                }
                            }
                            .foregroundStyle(RecallTheme.accent)
                            .disabled(isBusy)

                            Button("Not now") {
                                dismissed = true
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                            .disabled(isBusy)

                            Text("Yearly subscription, auto-renewable. Cancel at least 24 hours before renewal. Manage it in App Store → Subscriptions. This welcome offer shows once.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: 520)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
            }
        }
        .interactiveDismissDisabled(false)
    }

    private func perk(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(.primary)
    }
}
