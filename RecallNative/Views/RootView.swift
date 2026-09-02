import SwiftUI
import UIKit
import LocalAuthentication
import SwiftData

private enum RecallTab: Hashable { case decks, create, stats, settings }
struct ImportURLItem: Identifiable { let id = UUID(); let url: URL }
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var offerCards: [Flashcard]
    @Query private var offerReviews: [ReviewLog]
    @Query private var offerDecks: [Deck]
    @State private var selectedTab: RecallTab = .decks
    @State private var importURL: ImportURLItem?
    @State private var showingDesignLab = false
    @State private var showingLaunchOffer = false
    @State private var launchOfferScheduled = false
    @State private var lockState: LockState = .checking
    @State private var lastBackgroundedAt: Date?
    @State private var isAuthenticating = false
    @State private var observedCardCount: Int?
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("designTheme") private var designTheme = "recall"
    @AppStorage("designLabTaps") private var designLabTaps = 0
    @AppStorage("recall.launchOffer.v1.dismissed") private var launchOfferDismissed = false
    @AppStorage(BiometricLockService.enabledKey) private var biometricEnabled = false
    @AppStorage("iCloudEnabled") private var iCloudEnabled = false
    private let iCloud = ICloudSyncService()
    private enum LockState { case checking, locked, unlocked }
    private var colorScheme: ColorScheme? { switch appearance { case "light": return .light; case "dark": return .dark; default: return nil } }
    private var hasEarnedValue: Bool {
        LaunchOfferEligibility.hasEarnedValue(decks: offerDecks, cards: offerCards, reviews: offerReviews)
    }
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Decks", systemImage: "tray.full", value: RecallTab.decks) { DecksView() }.accessibilityIdentifier("tab.decks")
            Tab("Create", systemImage: "sparkles", value: RecallTab.create) { CreateView() }.accessibilityIdentifier("tab.create")
            Tab("Stats", systemImage: "chart.line.uptrend.xyaxis", value: RecallTab.stats) { StatsView() }.accessibilityIdentifier("tab.stats")
            Tab("Settings", systemImage: "gearshape", value: RecallTab.settings) { SettingsView() }.accessibilityIdentifier("tab.settings")
        }
        .tint(RecallTheme.accent).preferredColorScheme(colorScheme).background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .overlay { if lockState != .unlocked { lockOverlay } }
        .onAppear { observedCardCount = offerCards.count; Task { await checkAndLock() }; scheduleLaunchOfferIfEligible() }
        .onChange(of: offerCards.count) { _, newCount in
            recordCardCreationDelta(newCount)
            scheduleLaunchOfferIfEligible()
        }
        .onChange(of: offerReviews.count) { _, _ in scheduleLaunchOfferIfEligible() }
        .onChange(of: offerDecks.count) { _, _ in scheduleLaunchOfferIfEligible() }
        .onChange(of: scenePhase) { _, newPhase in if newPhase == .background { lastBackgroundedAt = Date(); syncBeforeSuspension() } }
        .onOpenURL { url in guard ["recall", "recall-flashcards"].contains(url.scheme?.lowercased()), url.host?.lowercased() == "import" else { return }; importURL = ImportURLItem(url: url) }
        .sheet(item: $importURL) { item in ImportLinkView(url: item.url) }
        .sheet(isPresented: $showingDesignLab) { DesignLabView() }
        .sheet(isPresented: $showingLaunchOffer, onDismiss: { launchOfferDismissed = true }) { LaunchOfferView() }
        .simultaneousGesture(LongPressGesture(minimumDuration: 1.2).onEnded { _ in designLabTaps += 1; if designLabTaps >= 7 { designLabTaps = 0; showingDesignLab = true } })
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in lastBackgroundedAt = Date() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in let elapsed = lastBackgroundedAt.map { Date().timeIntervalSince($0) } ?? .infinity; guard elapsed > BiometricLockService.gracePeriod else { return }; Task { await checkAndLock() } }
    }
    private func recordCardCreationDelta(_ newCount: Int) {
        guard let previous = observedCardCount else { observedCardCount = newCount; return }
        if newCount > previous { UsageMetricsStore.recordCreated(newCount - previous) }
        observedCardCount = newCount
    }
    private func syncBeforeSuspension() { guard iCloudEnabled else { return }; do { try modelContext.save(); _ = try iCloud.push(context: modelContext) } catch { } }
    private func scheduleLaunchOfferIfEligible() {
        guard !launchOfferDismissed, !launchOfferScheduled, hasEarnedValue else { return }
        launchOfferScheduled = true
        Task { @MainActor in try? await Task.sleep(for: .seconds(0.6)); guard !launchOfferDismissed else { return }; showingLaunchOffer = true }
    }
    @ViewBuilder private var lockOverlay: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                Image(systemName: "lock.fill").font(.system(size: 44, weight: .medium)).foregroundStyle(RecallTheme.accent).padding(.bottom, 28).accessibilityHidden(true)
                Text("Recall is locked").font(.title2.weight(.semibold))
                if lockState == .checking {
                    ProgressView().controlSize(.large).padding(.top, 28).accessibilityLabel("Checking lock status")
                } else {
                    Button { Task { await attemptUnlock() } } label: { Label("Unlock with Face ID", systemImage: "faceid").font(.headline).padding(.horizontal, 22).padding(.vertical, 13) }
                        .buttonStyle(.borderedProminent).tint(RecallTheme.accent).padding(.top, 28).accessibilityIdentifier("lock.unlock").accessibilityHint("Unlocks Recall using Face ID or your device passcode.").disabled(isAuthenticating)
                    Text("Use your device passcode if Face ID is unavailable.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.top, 14).padding(.horizontal, 32)
                }
            }
        }.transition(.opacity).zIndex(100)
    }
    @MainActor private func checkAndLock() async { guard biometricEnabled else { lockState = .unlocked; return }; lockState = .locked; await attemptUnlock() }
    @MainActor private func attemptUnlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let context = LAContext(); context.localizedFallbackTitle = "Use Passcode"; context.localizedCancelTitle = "Cancel"
        do { let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Recall"); if success { lockState = .unlocked } } catch { lockState = .locked }
    }
}
