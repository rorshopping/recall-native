import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import StoreKit
import LocalAuthentication

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("dailyGoal") private var dailyGoal = 20
    @AppStorage("iCloudEnabled") private var iCloudEnabled = false
    @AppStorage(BiometricLockService.enabledKey) private var biometricEnabled = false
    @StateObject private var subscriptions = SubscriptionService()
    @StateObject private var biometricLock = BiometricLockService()
    @State private var showingImporter = false
    @State private var backupURL: URL?
    @State private var showingShare = false
    @State private var showingResetConfirmation = false
    @State private var showingImportConfirmation = false
    @State private var pendingImportData: Data?
    @State private var showingAbout = false
    @State private var showingAIInfo = false
    @State private var showingAIImport = false
    @State private var showingLicenses = false
    @State private var showingPaywall = false
    @State private var errorMessage: String?
    @State private var iCloudAvailable: Bool?
    @State private var lastSync: Date?
    @State private var showingBiometricUnavailable = false
    private let iCloud = ICloudSyncService()

    private let companyName = "Richard Bäcker"
    private let supportEmail = "info.recall.apps@gmail.com"
    private let privacyEmail = "info.recall.apps@gmail.com"
    private let dailyGoalOptions = [5, 10, 20, 30, 50, 100, 200]

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }.pickerStyle(.menu)
                }

                Section("Study") {
                    Picker("Daily goal", selection: $dailyGoal) {
                        ForEach(dailyGoalOptions, id: \.self) { goal in
                            Text("\(goal) cards").tag(goal)
                        }
                    }
                    Text("Your daily goal is used for progress and streaks in Stats.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Haptic feedback", isOn: $hapticsEnabled)
                    Text("Slight feedback helps confirm Good and Easy grades. Turn it off for silent study.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Security") {
                    if biometricLock.available {
                        Toggle(isOn: Binding(
                            get: { biometricEnabled },
                            set: { value in
                                Task { await toggleBiometricLock(value) }
                            }
                        )) {
                            Label("Require Face ID / Touch ID", systemImage: "faceid")
                        }
                        Text("Require Face ID, Touch ID, or your device passcode when reopening Recall after a short background period.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Label("Face ID / Touch ID unavailable", systemImage: "faceid")
                            .foregroundStyle(.secondary)
                        Text("Set up Face ID or Touch ID in iOS Settings to protect your memories with an app lock.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Account & Premium") {
                    if subscriptions.isPremium {
                        Label("Premium active", systemImage: "checkmark.seal.fill").foregroundStyle(RecallTheme.accent)
                    } else {
                        Button { showingPaywall = true } label: { Label("Unlock Recall Full", systemImage: "sparkles") }
                        Text("Unlimited decks and cards, all study modes, and iCloud sync.").font(.caption).foregroundStyle(.secondary)
                    }
                    if !subscriptions.products.isEmpty {
                        ForEach(subscriptions.products) { product in
                            Button { Task { await subscriptions.purchase(product) } } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(product.displayName).foregroundStyle(.primary)
                                        Text(product.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                    Spacer()
                                    Text(product.displayPrice).font(.headline)
                                }
                            }
                        }
                    }
                    Button("Restore Purchases", systemImage: "arrow.clockwise") { Task { await subscriptions.restore() } }
                    Button("Manage Subscription", systemImage: "creditcard") {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") { openURL(url) }
                    }
                    Text("Auto-renewable subscription. The current App Store price is shown above. Payment is charged to your Apple ID. Cancel anytime in Settings → Apple Account → Subscriptions, at least 24 hours before renewal.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Sync") {
                    Toggle("iCloud sync", isOn: Binding(get: { iCloudEnabled }, set: { toggleICloud($0) }))
                    HStack {
                        Label("iCloud available", systemImage: "icloud")
                        Spacer()
                        Text(iCloudAvailable == nil ? "Checking…" : iCloudAvailable! ? "Yes" : "No").foregroundStyle(.secondary)
                    }
                    if iCloudEnabled {
                        Button("Sync now", systemImage: "arrow.triangle.2.circlepath") { syncNow() }
                        HStack { Text("Last sync"); Spacer(); Text(lastSync?.formatted(date: .abbreviated, time: .shortened) ?? "Never").foregroundStyle(.secondary) }
                        Text(iCloudAvailable == false ? "Sign in to iCloud in iOS Settings and enable the iCloud capability for this app before syncing." : "Your backup is stored in your personal iCloud Key-Value Store. Recall does not receive your Apple credentials.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Off by default. Your study data remains local until you enable sync.").font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Backup") {
                    Button("Export Backup", systemImage: "square.and.arrow.up") { exportBackup() }
                    Button("Import Backup", systemImage: "square.and.arrow.down") { showingImporter = true }
                    Text("Import replaces all current local decks, cards, and review history.").font(.caption).foregroundStyle(.secondary)
                }

                Section("On-device AI") {
                    Button { showingAIInfo = true } label: {
                        HStack { Label("Gemma 4 E2B", systemImage: "cpu.fill"); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
                    }
                    Button { showingAIImport = true } label: {
                        HStack { Label("Import from any AI", systemImage: "arrow.down.doc"); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
                    }
                    Text("Generation runs locally using LiteRT-LM. You can also import a deck generated by another AI using Recall's JSON format.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("About") {
                    Button { showingAbout = true } label: { Label("About Recall", systemImage: "info.circle") }
                    LabeledContent("Maker", value: companyName)
                    Button { if let url = URL(string: "mailto:\(supportEmail)") { openURL(url) } } label: { LabeledContent("Support", value: supportEmail) }
                    Button { if let url = URL(string: "mailto:\(privacyEmail)") { openURL(url) } } label: { Label("Privacy & data", systemImage: "hand.raised") }
                    Button { showingLicenses = true } label: { Label("Licenses & Attributions", systemImage: "doc.text.magnifyingglass") }
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                }

                Section {
                    Button("Reset local data", role: .destructive) { showingResetConfirmation = true }
                }
            }
            .navigationTitle("Settings")
            .task {
                biometricLock.refreshAvailability()
                iCloudAvailable = iCloud.isAvailable()
                lastSync = iCloud.lastSyncDate()
                await subscriptions.load()
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { prepareImport($0) }
            .sheet(isPresented: $showingShare) {
                if let backupURL { ShareLink(item: backupURL) { Label("Share backup", systemImage: "square.and.arrow.up") }.padding(40) }
            }
            .sheet(isPresented: $showingAbout) { AboutSheet() }
            .sheet(isPresented: $showingAIInfo) { OnDeviceAISettingsView() }
            .sheet(isPresented: $showingAIImport) { AIImportView() }
            .sheet(isPresented: $showingLicenses) { LicensesSheet() }
            .sheet(isPresented: $showingPaywall) { PaywallView(reason: "decks") }
            .alert("Settings error", isPresented: Binding(get: { errorMessage != nil || subscriptions.purchaseError != nil }, set: { if !$0 { errorMessage = nil; subscriptions.clearError() } })) {
                Button("OK") { errorMessage = nil; subscriptions.clearError() }
            } message: { Text(errorMessage ?? subscriptions.purchaseError ?? "") }
            .alert("Face ID / Touch ID unavailable", isPresented: $showingBiometricUnavailable) {
                Button("OK") {}
            } message: {
                Text("Set up Face ID or Touch ID in iOS Settings before enabling the app lock.")
            }
            .confirmationDialog("Import this backup?", isPresented: $showingImportConfirmation, titleVisibility: .visible) {
                Button("Import and Replace", role: .destructive) { performPendingImport() }
                Button("Cancel", role: .cancel) { pendingImportData = nil }
            } message: {
                Text("This replaces all current decks, cards, and review history. This cannot be undone.")
            }
            .confirmationDialog("Delete all local study data?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) { resetData() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func toggleBiometricLock(_ enabled: Bool) async {
        if enabled {
            guard biometricLock.available else {
                showingBiometricUnavailable = true
                return
            }
            guard await biometricLock.confirmEnable() else { return }
            biometricEnabled = true
        } else {
            biometricLock.setEnabled(false)
            biometricEnabled = false
        }
    }

    private func toggleICloud(_ enabled: Bool) {
        if enabled {
            let available = iCloud.isAvailable()
            iCloudAvailable = available
            guard available else {
                errorMessage = "iCloud is unavailable. Sign in to iCloud and enable the iCloud capability for this app before turning sync on."
                return
            }
            iCloudEnabled = true
            syncNow()
        } else { iCloudEnabled = false }
    }

    private func syncNow() {
        guard iCloudEnabled else { return }
        do {
            if try iCloud.push(context: modelContext) { lastSync = iCloud.lastSyncDate() }
            else { errorMessage = "iCloud is unavailable on this device." }
        } catch { errorMessage = error.localizedDescription }
    }

    private func exportBackup() {
        do {
            let data = try BackupService.makeBackup(context: modelContext)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Recall-Backup-\(Date().formatted(.iso8601.year().month().day())).json")
            try data.write(to: url, options: .atomic)
            backupURL = url
            showingShare = true
        } catch { errorMessage = error.localizedDescription }
    }

    private func prepareImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            _ = try BackupService.validate(data)
            pendingImportData = data
            showingImportConfirmation = true
        } catch { errorMessage = "That file is not a valid Recall backup." }
    }

    private func performPendingImport() {
        guard let data = pendingImportData else { return }
        do {
            try BackupService.restore(data, context: modelContext, replaceExisting: true)
            pendingImportData = nil
        } catch { errorMessage = error.localizedDescription }
    }

    private func resetData() {
        do {
            try modelContext.fetch(FetchDescriptor<ReviewLog>()).forEach(modelContext.delete)
            try modelContext.fetch(FetchDescriptor<Flashcard>()).forEach(modelContext.delete)
            try modelContext.fetch(FetchDescriptor<Deck>()).forEach(modelContext.delete)
            try modelContext.save()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section { Text("Recall turns what you learn into flashcards and helps you retain it with spaced repetition.") }
                Section("Privacy") {
                    Text("Your study material used for on-device generation stays on your iPhone. iCloud sync is optional and off by default.")
                }
                Section("Native") {
                    Label("SwiftUI", systemImage: "swift")
                    Label("SwiftData", systemImage: "externaldrive")
                    Label("LiteRT-LM", systemImage: "cpu")
                }
            }
            .navigationTitle("About Recall")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct LicensesSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Third-party software") {
                    license("Gemma 4 E2B", "Apache-2.0", "On-device model.")
                    license("LiteRT / LiteRT-LM", "Apache-2.0", "On-device inference runtime.")
                    license("SwiftUI / SwiftData / StoreKit", "Apple SDK", "Apple platform frameworks.")
                }
                Section {
                    Text("All bundled components are used under their respective licenses. Recall itself is proprietary software by Richard Bäcker.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Licenses & Attributions")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func license(_ name: String, _ license: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack { Text(name).font(.headline); Spacer(); Text(license).font(.caption.weight(.semibold)).foregroundStyle(RecallTheme.accent) }
            Text(note).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
