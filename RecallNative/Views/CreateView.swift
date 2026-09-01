import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct CreateView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingImporter = false
    @State private var showingText = false
    @State private var showingSave = false
    @State private var sourceText = ""
    @State private var deckName = ""
    @State private var isGenerating = false
    @State private var isDownloadingModel = false
    @State private var modelAvailable = false
    @State private var downloadProgress = ModelDownloadProgress(fraction: 0, bytesWritten: 0, totalBytes: 0)
    @State private var generated: [GeneratedCard] = []
    @State private var errorMessage: String?
    private let ai = LocalAIService()
    private let importer = DocumentImportService()
    private let modelStore = LiteRTModelStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Create").font(.largeTitle.bold())
                        Text("Turn anything you are learning into a focused review set.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    RecallCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles").font(.title2.weight(.semibold)).foregroundStyle(RecallTheme.accent)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("On-device AI").font(.headline)
                                    Text(modelAvailable ? "Gemma 4 is ready. Your content stays on this device." : "Gemma 4 runs privately on your iPhone. Download it once to enable generation.")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            if isDownloadingModel {
                                VStack(alignment: .leading, spacing: 8) {
                                    ProgressView(value: downloadProgress.fraction)
                                    HStack { Text("Downloading Gemma 4"); Spacer(); Text("\(Int(downloadProgress.fraction * 100))%") }.font(.caption.weight(.medium))
                                    HStack { Text(formatBytes(downloadProgress.bytesWritten)); Text("of"); Text(formatBytes(downloadProgress.totalBytes)); Spacer() }.font(.caption).foregroundStyle(.secondary)
                                }
                            } else if !modelAvailable {
                                Button { downloadModel() } label: {
                                    Label("Download Gemma 4", systemImage: "arrow.down.circle.fill").frame(maxWidth: .infinity)
                                }.buttonStyle(.borderedProminent).controlSize(.large)
                            } else {
                                Label("Model ready", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                        }
                    }
                    Button { showingText = true } label: { CreateAction(icon: "text.alignleft", title: "Paste notes", subtitle: "Best for articles, lectures, and notes") }
                        .buttonStyle(.plain).disabled(!modelAvailable).opacity(modelAvailable ? 1 : 0.55)
                    Button { showingImporter = true } label: { CreateAction(icon: "doc.richtext", title: "Import PDF", subtitle: "Up to 5 pages, processed on device") }
                        .buttonStyle(.plain).disabled(!modelAvailable).opacity(modelAvailable ? 1 : 0.55)
                    if isGenerating {
                        RecallCard { HStack(spacing: 12) { ProgressView(); VStack(alignment: .leading, spacing: 2) { Text("Creating your cards").font(.headline); Text("Gemma 4 is running locally on this device.").font(.subheadline).foregroundStyle(.secondary) } } }
                    }
                    if !generated.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Text("Ready to review").font(.title3.bold()); Spacer(); Text("\(generated.count) cards").font(.subheadline.weight(.medium)).foregroundStyle(.secondary) }
                            ForEach(generated) { card in RecallCard { Text(card.question).font(.headline); Divider().padding(.vertical, 6); Text(card.answer).foregroundStyle(.secondary) } }
                            Button { deckName = deckName.isEmpty ? suggestedDeckName : deckName; showingSave = true } label: { Label("Save to library", systemImage: "square.and.arrow.down.fill").frame(maxWidth: .infinity) }
                                .buttonStyle(.borderedProminent).controlSize(.large)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(RecallTheme.canvas)
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.inline)
            .task { modelAvailable = await modelStore.modelURL() != nil }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { handleImport($0) }
            .sheet(isPresented: $showingText) {
                NavigationStack {
                    TextEditor(text: $sourceText).font(.body).padding(.horizontal, 8)
                        .navigationTitle("Paste notes").navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingText = false } }
                            ToolbarItem(placement: .confirmationAction) { Button("Generate") { showingText = false; generate() }.disabled(sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                        }
                }.presentationDetents([.large])
            }
            .sheet(isPresented: $showingSave) { SaveDeckSheet(name: $deckName) { saveGeneratedCards() } }
            .alert("Couldn’t create cards", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
        }
    }

    private var suggestedDeckName: String {
        let first = sourceText.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ").prefix(5).joined(separator: " ")
        return first.isEmpty ? "New deck" : first.capitalized
    }

    private func downloadModel() {
        guard !isDownloadingModel else { return }
        isDownloadingModel = true
        downloadProgress = ModelDownloadProgress(fraction: 0, bytesWritten: 0, totalBytes: 0)
        Task {
            do {
                _ = try await modelStore.downloadModel { progress in
                    Task { @MainActor in downloadProgress = progress }
                }
                await MainActor.run { modelAvailable = true; isDownloadingModel = false }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isDownloadingModel = false }
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        do { sourceText = try importer.extractText(from: url); generate() } catch { errorMessage = error.localizedDescription }
    }

    private func generate() {
        guard !isGenerating else { return }
        guard modelAvailable else { errorMessage = AIServiceError.modelMissing.localizedDescription; return }
        isGenerating = true; generated = []
        Task { @MainActor in
            do { generated = try await ai.generateFlashcards(from: sourceText) } catch { errorMessage = error.localizedDescription }
            isGenerating = false
        }
    }

    private func saveGeneratedCards() {
        let deck = Deck(name: deckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New deck" : deckName)
        modelContext.insert(deck)
        generated.forEach { modelContext.insert(Flashcard(question: $0.question, answer: $0.answer, deck: deck)) }
        generated = []; sourceText = ""; deckName = ""; showingSave = false
    }

    private func formatBytes(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
}

private struct CreateAction: View {
    let icon: String; let title: String; let subtitle: String
    var body: some View {
        RecallCard {
            HStack(spacing: 16) {
                Image(systemName: icon).font(.title2.weight(.semibold)).frame(width: 48, height: 48)
                    .background(RecallTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous)).foregroundStyle(RecallTheme.accent)
                VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
                Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
        }
    }
}

private struct SaveDeckSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var name: String
    let save: () -> Void
    var body: some View {
        NavigationStack {
            Form { Section("Deck") { TextField("Deck name", text: $name) }; Section { Text("Your generated cards will be saved locally and available in your library.").font(.subheadline).foregroundStyle(.secondary) } }
                .navigationTitle("Save cards")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } } }
        }.presentationDetents([.medium])
    }
}
