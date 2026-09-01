import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var decks: [Deck]
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("dailyGoal") private var dailyGoal = 20
    @StateObject private var subscriptions = SubscriptionService()
    @State private var showingImporter = false
    @State private var backupURL: URL?
    @State private var showingShare = false
    @State private var showingAbout = false
    @State private var showingAIInfo = false
    @State private var showingLicenses = false
    @State private var showingResetConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") { Picker("Theme", selection: $appearance) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }.pickerStyle(.menu) }
                Section("Study") { Stepper("Daily goal · \(dailyGoal) cards", value: $dailyGoal, in: 5...200, step: 5); Toggle("Haptic feedback", isOn: $hapticsEnabled) }
                Section("Account & Premium") {
                    if subscriptions.isPremium { Label("Premium active", systemImage: "checkmark.seal.fill").foregroundStyle(RecallTheme.accent) }
                    else if !subscriptions.products.isEmpty { ForEach(subscriptions.products) { product in Button { Task { await subscriptions.purchase(product) } } label: { HStack { VStack(alignment: .leading) { Text(product.displayName).foregroundStyle(.primary); Text(product.description).font(.caption).foregroundStyle(.secondary).lineLimit(2) }; Spacer(); Text(product.displayPrice).font(.headline) } } } }
                    else { Label("Premium", systemImage: "star.fill"); Text("Premium products are unavailable until App Store Connect products are configured.").font(.caption).foregroundStyle(.secondary) }
                    Button("Restore Purchases", systemImage: "arrow.clockwise") { Task { await subscriptions.restore() } }
                }
                Section("Sync & Backup") {
                    Label("iCloud Sync", systemImage: "icloud")
                    Text("Local SwiftData storage is active. CloudKit synchronization requires the iCloud container and entitlements to be configured for this bundle before it can be safely enabled.").font(.caption).foregroundStyle(.secondary)
                    Button("Export Backup", systemImage: "square.and.arrow.up") { exportBackup() }
                    Button("Import Backup", systemImage: "square.and.arrow.down") { showingImporter = true }
                }
                Section("On-device AI") {
                    Button { showingAIInfo = true } label: { HStack { Label("Gemma 4", systemImage: "cpu.fill"); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) } }
                    Text("Generation runs locally using LiteRT-LM.").font(.caption).foregroundStyle(.secondary)
                }
                Section("About") {
                    Button { showingAbout = true } label: { HStack { Label("About Recall", systemImage: "info.circle"); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) } }
                    Button { showingLicenses = true } label: { HStack { Label("Licenses & Attributions", systemImage: "doc.text.magnifyingglass"); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) } }
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                }
                Section("Developer") { Label("Recall Native", systemImage: "swift"); Text("Native SwiftUI implementation with on-device AI.").font(.caption).foregroundStyle(.secondary) }
                Section { Button("Reset local data", role: .destructive) { showingResetConfirmation = true } }
            }
            .navigationTitle("Settings")
            .task { await subscriptions.load() }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in importBackup(result) }
            .sheet(isPresented: $showingShare) { if let backupURL { ShareSheet(url: backupURL) } }
            .sheet(isPresented: $showingAbout) { AboutSheet() }
            .sheet(isPresented: $showingAIInfo) { AIInfoSheet() }
            .sheet(isPresented: $showingLicenses) { LicensesSheet() }
            .alert("Backup error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
            .alert("Purchase issue", isPresented: Binding(get: { subscriptions.purchaseError != nil }, set: { if !$0 { subscriptions.clearError() } })) { Button("OK") { subscriptions.clearError() } } message: { Text(subscriptions.purchaseError ?? "") }
            .confirmationDialog("Delete all local study data?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) { resetData() }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private func exportBackup() {
        do {
            let data = try BackupService.makeBackup(context: modelContext)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Recall-Backup-\(Date().formatted(.iso8601.year().month().day())).json")
            try data.write(to: url, options: .atomic); backupURL = url; showingShare = true
        } catch { errorMessage = error.localizedDescription }
    }

    private func importBackup(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let secured = url.startAccessingSecurityScopedResource(); defer { if secured { url.stopAccessingSecurityScopedResource() } }
        do { try BackupService.restore(try Data(contentsOf: url), context: modelContext) } catch { errorMessage = error.localizedDescription }
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

private struct ShareSheet: View { let url: URL; var body: some View { VStack(spacing: 16) { Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(RecallTheme.accent); Text("Backup ready").font(.headline); ShareLink(item: url) { Label("Share backup", systemImage: "square.and.arrow.up") }.buttonStyle(.borderedProminent) } .padding(40) } }
private struct AboutSheet: View { @Environment(\.dismiss) private var dismiss; var body: some View { NavigationStack { List { Section { Text("Recall turns what you learn into flashcards and helps you retain it with spaced repetition.") }; Section("Native") { Label("SwiftUI", systemImage: "swift"); Label("SwiftData", systemImage: "externaldrive"); Label("LiteRT-LM", systemImage: "cpu") } }.navigationTitle("About Recall").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } } } } }
private struct AIInfoSheet: View { @Environment(\.dismiss) private var dismiss; var body: some View { NavigationStack { List { Section("Model") { Text("Gemma 4 E2B").font(.headline); Text("Downloaded on demand and executed locally with LiteRT-LM.").foregroundStyle(.secondary) }; Section("Privacy") { Text("Your study material is processed on-device for generation.").foregroundStyle(.secondary) } }.navigationTitle("On-device AI").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } } } } }
private struct LicensesSheet: View { @Environment(\.dismiss) private var dismiss; var body: some View { NavigationStack { List { Section("Third-party software") { Label("LiteRT / LiteRT-LM", systemImage: "cpu"); Label("Gemma 4", systemImage: "sparkles"); Text("License notices for bundled and downloaded third-party components must be shipped with the release build.").font(.caption).foregroundStyle(.secondary) } }.navigationTitle("Licenses").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } } } } }
