import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct AIImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var json = ""
    @State private var copied = false
    @State private var showingImporter = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false
    @State private var importedName = ""
    @State private var importedCount = 0

    private let prompt = """
Create a set of flashcards for studying. Reply with ONLY valid JSON in this exact shape:

{
  \"deck\": \"Topic name\",
  \"cards\": [
    { \"front\": \"Question or term\", \"back\": \"Answer or definition\", \"hint\": \"optional clue\", \"tags\": \"optional, comma separated\" }
  ]
}

Rules:
- Include 10-30 cards.
- Keep front/back short and clear.
- Output no text outside the JSON.
"""

    var body: some View {
        NavigationStack {
            Form {
                Section("Generate with AI") {
                    Text("Use any AI you already have. Recall does not need an API key and your material stays on this device.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("1. Copy the prompt") {
                    Button(copied ? "Copied" : "Copy the prompt", systemImage: copied ? "checkmark" : "doc.on.doc") {
                        UIPasteboard.general.string = prompt
                        copied = true
                        Task { try? await Task.sleep(for: .seconds(2.5)); await MainActor.run { copied = false } }
                    }
                    Text("Paste it into ChatGPT, Claude, or another AI, then paste the JSON it returns below.")
                        .font(.caption).foregroundStyle(.secondary)
                    DisclosureGroup("Show prompt") { Text(prompt).font(.caption.monospaced()).textSelection(.enabled) }
                }
                Section("2. Paste the JSON") {
                    TextEditor(text: $json)
                        .frame(minHeight: 190)
                        .overlay(alignment: .topLeading) {
                            if json.isEmpty { Text("Paste the JSON your AI returned…").foregroundStyle(.tertiary).padding(.top, 8).allowsHitTesting(false) }
                        }
                    Button("Import a JSON file instead", systemImage: "doc.badge.plus") { showingImporter = true }
                }
                Section {
                    Button("Create deck", systemImage: "plus.rectangle.on.folder.fill") { createDeck() }
                        .frame(maxWidth: .infinity)
                        .disabled(json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("AI Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                let secured = url.startAccessingSecurityScopedResource()
                defer { if secured { url.stopAccessingSecurityScopedResource() } }
                do { json = try String(contentsOf: url, encoding: .utf8) }
                catch { errorMessage = "Could not read that JSON file." }
            }
            .alert("Could not import", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") {} } message: { Text(errorMessage ?? "") }
            .alert("Deck created", isPresented: $showingSuccess) { Button("Done") { dismiss() } } message: { Text("\(importedName) · \(importedCount) cards added.") }
        }
    }

    private func createDeck() {
        do {
            let parsed = try DeckImportService.parse(Data(json.utf8))
            let deck = Deck(name: parsed.name, emoji: "📚")
            modelContext.insert(deck)
            for card in parsed.cards {
                modelContext.insert(Flashcard(question: card.front.trimmingCharacters(in: .whitespacesAndNewlines), answer: card.back.trimmingCharacters(in: .whitespacesAndNewlines), hint: card.hint, tags: card.tags, deck: deck))
            }
            try modelContext.save()
            importedName = parsed.name
            importedCount = parsed.cards.count
            json = ""
            showingSuccess = true
        } catch {
            errorMessage = "Paste valid JSON in the supported { deck, cards } format."
        }
    }
}
