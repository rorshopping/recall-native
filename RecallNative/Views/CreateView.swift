import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct CreateView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingImporter = false
    @State private var showingText = false
    @State private var sourceText = ""
    @State private var isGenerating = false
    @State private var generated: [GeneratedCard] = []
    @State private var errorMessage: String?
    private let ai = LocalAIService()
    private let importer = DocumentImportService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Create")
                        .font(.largeTitle.bold())
                    Text("Give Recall something worth remembering.")
                        .foregroundStyle(.secondary)

                    Button { showingText = true } label: {
                        CreateAction(icon: "text.alignleft", title: "Paste notes", subtitle: "Turn your notes into flashcards")
                    }
                    .buttonStyle(.plain)

                    Button { showingImporter = true } label: {
                        CreateAction(icon: "doc.richtext", title: "Import PDF", subtitle: "Up to 5 pages for on-device generation")
                    }
                    .buttonStyle(.plain)

                    if isGenerating {
                        ProgressView("Generating cards…")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }

                    if !generated.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Preview").font(.title3.bold())
                            ForEach(generated) { card in
                                RecallCard {
                                    Text(card.question).font(.headline)
                                    Text(card.answer).foregroundStyle(.secondary).padding(.top, 4)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(RecallTheme.canvas)
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
                handleImport(result)
            }
            .sheet(isPresented: $showingText) {
                NavigationStack {
                    TextEditor(text: $sourceText)
                        .padding()
                        .navigationTitle("Paste notes")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Generate") { showingText = false; generate() }
                                    .disabled(sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                }
            }
            .alert("Couldn’t create cards", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        do {
            sourceText = try importer.extractText(from: url)
            generate()
        } catch { errorMessage = error.localizedDescription }
    }

    private func generate() {
        isGenerating = true
        Task {
            do {
                generated = try await ai.generateFlashcards(from: sourceText)
            } catch { errorMessage = error.localizedDescription }
            isGenerating = false
        }
    }
}

private struct CreateAction: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        RecallCard {
            HStack(spacing: 16) {
                Image(systemName: icon).font(.title2).frame(width: 46, height: 46).background(RecallTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
        }
    }
}
