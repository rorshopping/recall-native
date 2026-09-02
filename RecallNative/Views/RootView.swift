import SwiftUI
import UIKit
import LocalAuthentication

private enum RecallTab: Hashable {
    case home, decks, create, stats, settings
}

/// `URL` is not `Identifiable`, but `sheet(item:)` needs an `Identifiable`
/// item. This wrapper is the smallest adapter that lets `RootView` present
/// `ImportLinkView` only when an import URL is non-nil.
struct ImportURLItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct RootView: View {
    @State private var selectedTab: RecallTab = .home
    @State private var importURL: ImportURLItem?
    @State private var showingDesignLab = false
    @State private var showingHomeReview = false
    @State private var lockState: LockState = .checking
    @State private var lastBackgroundedAt: Date?
    @State private var isAuthenticating = false
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("designTheme") private var designTheme = "recall"
    @AppStorage("designLabTaps") private var designLabTaps = 0
    @AppStorage(BiometricLockService.enabledKey) private var biometricEnabled = false

    private enum LockState {
        case checking, locked, unlocked
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        GeometryReader { proxy in
            TabView(selection: $selectedTab) {
                HomeView(onStartReview: { showingHomeReview = true })
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(RecallTab.home)
                DecksView()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .tabItem { Label("Decks", systemImage: "tray.full") }
                    .tag(RecallTab.decks)
                CreateView()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .tabItem { Label("Create", systemImage: "sparkles") }
                    .tag(RecallTab.create)
                StatsView()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .tabItem { Label("Stats", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(RecallTab.stats)
                SettingsView()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(RecallTab.settings)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .tint(RecallTheme.accent)
        .preferredColorScheme(colorScheme)
        .overlay {
            if lockState != .unlocked { lockOverlay }
        }
        .onAppear {
            Task { await checkAndLock() }
        }
        .onOpenURL { url in
            guard ["recall", "recall-flashcards"].contains(url.scheme?.lowercased()), url.host?.lowercased() == "import" else { return }
            importURL = ImportURLItem(url: url)
        }
        .sheet(item: $importURL) { item in ImportLinkView(url: item.url) }
        .sheet(isPresented: $showingDesignLab) { DesignLabView() }
        .fullScreenCover(isPresented: $showingHomeReview) { ReviewView() }
        .simultaneousGesture(LongPressGesture(minimumDuration: 1.2).onEnded { _ in
            designLabTaps += 1
            if designLabTaps >= 7 {
                designLabTaps = 0
                showingDesignLab = true
            }
        })
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            lastBackgroundedAt = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            let elapsed = lastBackgroundedAt.map { Date().timeIntervalSince($0) } ?? .infinity
            guard elapsed > BiometricLockService.gracePeriod else { return }
            Task { await checkAndLock() }
        }
    }

    @ViewBuilder
    private var lockOverlay: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(RecallTheme.accent)
                    .padding(.bottom, 28)
                Text("Recall is locked").font(.title2.weight(.semibold))
                if lockState == .checking {
                    ProgressView().controlSize(.large).padding(.top, 28)
                } else {
                    Button { Task { await attemptUnlock() } } label: {
                        Label("Unlock with Face ID", systemImage: "faceid")
                            .font(.headline)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RecallTheme.accent)
                    .padding(.top, 28)
                    .disabled(isAuthenticating)
                    Text("Use your device passcode if Face ID is unavailable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)
                        .padding(.horizontal, 32)
                }
            }
        }
        .transition(.opacity)
        .zIndex(100)
    }

    @MainActor
    private func checkAndLock() async {
        guard biometricEnabled else { lockState = .unlocked; return }
        lockState = .locked
        await attemptUnlock()
    }

    @MainActor
    private func attemptUnlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        context.localizedCancelTitle = "Cancel"
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Recall")
            if success { lockState = .unlocked }
        } catch {
            lockState = .locked
        }
    }
}
