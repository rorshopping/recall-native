import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("dailyGoal") private var dailyGoal = 20
    @AppStorage("iCloudEnabled") private var iCloudEnabled = false
    @StateObject private var subscriptions = SubscriptionService()
    @State private var showingImporter = false
    @State private var backupURL: URL?
    @State private var showingShare = false
    @State private var showingResetConfirmation = false
    @State private var showingAbout = false
    @State private var showingAIInfo = false
    @State private var showingLicenses = false
    @State private var showingPaywall = false
    @State private var errorMessage: String?
    @State private var iCloudAvailable: Bool?
    @State private var lastSync: Date?
    private let iCloud = ICloudSyncService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") { Picker("Theme", selection: $appearance) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }.pickerStyle(.menu) }
                Section("Study") { Stepper("Daily goal · \(dailyGoal) cards", value: $dailyGoal, in: 5...200, step: 5); Toggle("Haptic feedback", isOn: $hapticsEnabled) }
                Section("Account & Premium") {
                    if subscriptions.isPremium {
                        Label("Premium active", systemImage: "checkmark.seal.fill").foregroundStyle(RecallTheme.accent)
                    } else {
                        Button { showingPaywall = true } label: {
                            Label("Unlock Recall Full", systemImage: "sparkles")
                        }
                        Text("Unlimited decks and cards, all study modes, and iCloud sync.").font(.caption).foregroundStyle(.secondary)
                    }
                    if !subscriptions.products.isEmpty {
                        ForEach(subscriptions.products) { product in
                            Button { Task { await subscriptions.purchase(product) } } label: {
                                HStack { VStack(alignment: .leading) { Text(product.displayName).foregroundStyle(.primary); Text(product.description).font(.caption).foregroundStyle(.secondary).lineLimit(2) }; Spacer(); Text(product.displayPrice).font(.headline) }
                            }
                        }
                    }
                    Button("Restore Purchases", systemImage: "arrow.clockwise") { Task { await subscriptions.restore() } }
                }
                Section("Sync") {
                    Toggle("iCloud sync", isOn: Binding(get: { iCloudEnabled }, set: { toggleICloud($0) }))
                    HStack { Label("iCloud available", systemImage: "icloud"); Spacer(); Text(iCloudAvailable == nil ? "Checking…" : iCloudAvailable! ? "Yes" : "No").foregroundStyle(.secondary) }
                    if iCloudEnabled {
                        Button("Sync now", systemImage: "arrow.triangle.2.circlepath") { syncNow() }
                        HStack { Text("Last sync"); Spacer(); Text(lastSync?.formatted(date: .abbreviated, time: .shortened) ?? "Never").foregroundStyle(.secondary) }
                        Text(iCloudAvailable == false ? "Sign in to iCloud in iOS Settings and enable the iCloud capability for this app before syncing." : "Your backup is stored in your personal iCloud Key-Value Store. Recall does not receive your Apple credentials.").font(.caption).foregroundStyle(.secondary)
                    } else { Text("Off by default. Your study data remains local until you enable sync.").font(.caption).foregroundStyle(.secondary) }
                }
                Section("Backup") {
                    Button("Export Backup", systemImage: "square.and.arrow.up") { exportBackup() }
                    Button("Import Backup", systemImage: "square.and.arrow.down") { showingImporter = true }
                }
                Section("On-device AI") {
                    Button { showingAIInfo = true } label: { HStack { Label("Gemma 4 E2B", systemImage: "cpu.fill"); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) } }
                    Text("Generation runs locally using LiteRT-LM. Your notes and PDFs are not uploaded for generation.").font(.caption).foregroundStyle(.secondary)
                }
                Section("About") {
                    Button { showingAbout = true } label: { Label("About Recall", systemImage: "info.circle") }
                    Button { showingLicenses = true } label: { Label("Licenses & Attributions", systemImage: "doc.text.magnifyingglass") }
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                }
                Section { Button("Reset local data", role: .destructive) { showingResetConfirmation = true } }
            }
            .navigationTitle("Settings")
            .task { iCloudAvailable = iCloud.isAvailable(); lastSync = iCloud.lastSyncDate(); await subscriptions.load() }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { importBackup($0) }
            .sheet(isPresented: $showingShare) { if let backupURL { ShareLink(item: backupURL) { Label("Share backup", systemImage: "square.and.arrow.up") }.padding(40) } }
            .sheet(isPresented: $showingAbout) { AboutSheet() }
            .sheet(isPresented: $showingAIInfo) { AIInfoSheet() }
            .sheet(isPresented: $showingLicenses) { LicensesSheet() }
            .sheet(isPresented: $showingPaywall) { PaywallView(reason: "decks") }
            .alert("Settings error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
            .confirmationDialog("Delete all local study data?", isPresented: $showingResetConfirmation, titleVisibility: .visible) { Button("Delete Everything", role: .destructive) { resetData() }; Button("Cancel", role: .cancel) {} }
        }
    }

    private func toggleICloud(_ enabled: Bool) {
        if enabled {
            let available = iCloud.isAvailable(); iCloudAvailable = available
            guard available else { errorMessage = "iCloud is unavailable. Sign in to iCloud and enable the iCloud capability for this app before turning sync on."; return }
            iCloudEnabled = true; syncNow()
        } else { iCloudEnabled = false }
    }
    private func syncNow() {
        guard iCloudEnabled else { return }
        do { if try iCloud.push(context: modelContext) { iCloud.markSynced(); lastSync = iCloud.lastSyncDate() } else { errorMessage = "iCloud is unavailable on this device." } } catch { errorMessage = error.localizedDescription }
    }
    private func exportBackup() { do { let data = try BackupService.makeBackup(context: modelContext); let url = FileManager.default.temporaryDirectory.appendingPathComponent("Recall-Backup-\(Date().formatted(.iso8601.year().month().day())).json"); try data.write(to: url, options: .atomic); backupURL = url; showingShare = true } catch { errorMessage = error.localizedDescription } }
    private func importBackup(_ result: Result<[URL], Error>) { guard case .success(let urls) = result, let url = urls.first else { return }; let secured = url.startAccessingSecurityScopedResource(); defer { if secured { url.stopAccessingSecurityScopedResource() } }; do { try BackupService.restore(try Data(contentsOf: url), context: modelContext, replaceExisting: true) } catch { errorMessage = error.localizedDescription } }
    private func resetData() { do { try modelContext.fetch(FetchDescriptor<ReviewLog>()).forEach(modelContext.delete); try modelContext.fetch(FetchDescriptor<Flashcard>()).forEach(modelContext.delete); try modelContext.fetch(FetchDescriptor<Deck>()).forEach(modelContext.delete); try modelContext.save() } catch { errorMessage = error.localizedDescription } }
}

private struct AboutSheet: View { @Environment(\.dismiss) private var dismiss; var body: some View { NavigationStack { List { Section { Text("Recall turns what you learn into flashcards and helps you retain it with spaced repetition.") }; Section("Native") { Label("SwiftUI", systemImage: "swift"); Label("SwiftData", systemImage: "externaldrive"); Label("LiteRT-LM", systemImage: "cpu") } }.navigationTitle("About Recall").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } } } } }
private struct AIInfoSheet: View { @Environment(\.dismiss) private var dismiss; var body: some View { NavigationStack { List { Section("Model") { Text("Gemma 4 E2B").font(.headline); Text("Downloaded on demand and executed locally with LiteRT-LM.").foregroundStyle(.secondary) }; Section("Privacy") { Text("Study material is processed on-device for generation.").foregroundStyle(.secondary) } }.navigationTitle("On-device AI").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } } } } }
private struct LicensesSheet: View { @Environment(\.dismiss) private var dismiss; var body: some View { NavigationStack { List { Section("Third-party software") { Label("LiteRT / LiteRT-LM", systemImage: "cpu"); Label("Gemma 4", systemImage: "sparkles"); Text("Ship the applicable third-party license notices with the release build.").font(.caption).foregroundStyle(.secondary) } }.navigationTitle("Licenses").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } } } } }
