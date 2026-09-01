import SwiftUI
import StoreKit

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("dailyGoal") private var dailyGoal = 20
    @StateObject private var subscriptions = SubscriptionService()
    @State private var showingAbout = false
    @State private var showingAIInfo = false
    @State private var showingLicenses = false
    @State private var showingResetConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.menu)
                }

                Section("Study") {
                    Stepper("Daily goal · \(dailyGoal) cards", value: $dailyGoal, in: 5...200, step: 5)
                    Toggle("Haptic feedback", isOn: $hapticsEnabled)
                }

                Section("Account & Premium") {
                    if subscriptions.isPremium {
                        Label("Premium active", systemImage: "checkmark.seal.fill").foregroundStyle(RecallTheme.accent)
                    } else if subscriptions.products.isEmpty {
                        Label("Premium", systemImage: "star.fill")
                        Text("Premium products become available when App Store Connect products are configured.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(subscriptions.products) { product in
                            Button { Task { await subscriptions.purchase(product) } } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(product.displayName).foregroundStyle(.primary)
                                        Text(product.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                    Spacer(); Text(product.displayPrice).font(.headline)
                                }
                            }
                        }
                    }
                    Button("Restore Purchases", systemImage: "arrow.clockwise") { Task { await subscriptions.restore() } }
                }

                Section("Sync & Backup") {
                    HStack {
                        Label("iCloud Sync", systemImage: "icloud")
                        Spacer(); Text("On-device storage").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Your decks and cards are currently stored locally. iCloud/CloudKit synchronization will be connected to the native persistence layer before release.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Export Backup", systemImage: "square.and.arrow.up") { }
                    Button("Import Backup", systemImage: "square.and.arrow.down") { }
                }

                Section("On-device AI") {
                    Button { showingAIInfo = true } label: {
                        HStack { Label("Gemma 4", systemImage: "cpu.fill"); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
                    }
                    Text("AI generation runs locally on your device. Model data and your study content are not sent to a remote AI service.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("About") {
                    Button { showingAbout = true } label: { HStack { Label("About Recall", systemImage: "info.circle"); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) } }
                    Button { showingLicenses = true } label: { HStack { Label("Licenses & Attributions", systemImage: "doc.text.magnifyingglass"); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) } }
                    HStack { Text("Version"); Spacer(); Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0").foregroundStyle(.secondary) }
                    HStack { Text("Build"); Spacer(); Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1").foregroundStyle(.secondary) }
                }

                Section("Developer") {
                    Label("Recall Native", systemImage: "swift")
                    Text("A native SwiftUI implementation of Recall, with on-device AI powered by LiteRT.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section {
                    Button("Reset local data", role: .destructive) { showingResetConfirmation = true }
                }
            }
            .navigationTitle("Settings")
            .task { await subscriptions.load() }
            .alert("Purchase issue", isPresented: Binding(get: { subscriptions.purchaseError != nil }, set: { if !$0 { subscriptions.clearError() } })) {
                Button("OK") { subscriptions.clearError() }
            } message: { Text(subscriptions.purchaseError ?? "") }
            .sheet(isPresented: $showingAbout) { AboutSheet() }
            .sheet(isPresented: $showingAIInfo) { AIInfoSheet() }
            .sheet(isPresented: $showingLicenses) { LicensesSheet() }
            .confirmationDialog("Delete all local study data?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) { }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
}

private struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section { Text("Recall helps you turn what you learn into flashcards and review them with spaced repetition.").font(.body) }
                Section("Native") { Label("SwiftUI", systemImage: "swift"); Label("SwiftData", systemImage: "externaldrive"); Label("LiteRT", systemImage: "cpu") }
            }.navigationTitle("About Recall").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct AIInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Model") { Text("Gemma 4 E2B").font(.headline); Text("The model is downloaded once and executed locally using LiteRT-LM.").foregroundStyle(.secondary) }
                Section("Privacy") { Text("Generated content is processed on-device. The app does not need to upload your notes or PDFs to generate cards.").foregroundStyle(.secondary) }
            }.navigationTitle("On-device AI").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct LicensesSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Third-party software") {
                    Label("LiteRT / LiteRT-LM", systemImage: "cpu")
                    Label("Gemma 4", systemImage: "sparkles")
                    Text("See the distributed third-party license notices for the exact versions and license terms included with this build.").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Licenses").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
