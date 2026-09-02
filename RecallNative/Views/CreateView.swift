import SwiftUI
import UniformTypeIdentifiers
import SwiftData

private enum CreateMode: String, CaseIterable, Identifiable {
    case flashcards = "Flashcards", guide = "Study guide", exam = "Practice exam", ask = "Ask", explain = "Explain"
    var id: String { rawValue }
    var icon: String { switch self { case .flashcards: return "rectangle.stack.fill"; case .guide: return "book.pages.fill"; case .exam: return "checklist"; case .ask: return "bubble.left.and.bubble.right.fill"; case .explain: return "lightbulb.fill" } }
}

struct CreateView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var decks: [Deck]
    @StateObject private var subscriptions = SubscriptionService()
    @State private var showingImporter = false
    @State private var showingSave = false
    @State private var showingPaywall = false
    @State private var sourceText = ""
    @State private var sourceName = ""
    @State private var deckName = ""
    @State private var selectedDeckID: UUID?
    @State private var mode: CreateMode = .flashcards
    @State private var askInput = ""
    @State private var explainInput = ""
    @State private var moreWaysExpanded = false
    @State private var isGenerating = false
    @State private var isDownloadingModel = false
    @State private var modelAvailable = false
    @State private var downloadProgress = ModelDownloadProgress(fraction: 0, bytesWritten: 0, totalBytes: 0)
    @State private var generated: [GeneratedCard] = []
    @State private var resultObject: [String: Any]?
    @State private var errorMessage: String?
    private let ai = LocalAIService()
    private let advancedAI = AdvancedAIService()
    private let importer = DocumentImportService()
    private let modelStore = LiteRTModelStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) { Text("Create").font(.largeTitle.bold()); Text("Turn your material into something you can study.").font(.subheadline).foregroundStyle(.secondary) }
                    RecallCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What do you want to study?").font(.headline)
                            Button { showingImporter = true } label: {
                                HStack(spacing: 12) { Image(systemName: "doc.richtext").font(.title2).foregroundStyle(RecallTheme.accent); VStack(alignment: .leading, spacing: 3) { Text(sourceName.isEmpty ? "Upload PDF" : sourceName).font(.headline).foregroundStyle(.primary); Text(sourceName.isEmpty ? "Up to 5 pages" : "Ready for on-device AI").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) }.padding(.vertical, 5)
                            }.buttonStyle(.plain)
                            HStack { Rectangle().frame(height: 1).foregroundStyle(.quaternary); Text("or").font(.caption).foregroundStyle(.tertiary); Rectangle().frame(height: 1).foregroundStyle(.quaternary) }
                            TextField("Enter a topic or paste notes", text: $sourceText, axis: .vertical).lineLimit(2...6).textFieldStyle(.roundedBorder)
                            if !sourceName.isEmpty { Button("Remove PDF", role: .destructive) { sourceName = ""; sourceText = "" } }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Create as").font(.headline)
                        Picker("Create as", selection: $mode) { Text("Flashcards").tag(CreateMode.flashcards); Text("Study guide").tag(CreateMode.guide); Text("Practice exam").tag(CreateMode.exam) }.pickerStyle(.segmented)
                        if mode == .flashcards { Text("10-25 cards · recommended").font(.caption).foregroundStyle(.secondary) }
                    }
                    RecallCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Image(systemName: "sparkles").foregroundStyle(RecallTheme.accent); Text("On-device AI").font(.headline); Spacer(); if modelAvailable { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) } }
                            Text(modelAvailable ? "Gemma 4 is ready. Nothing leaves your iPhone." : "Download the ~2.6 GB model once. Generation then runs locally.").font(.subheadline).foregroundStyle(.secondary)
                            if isDownloadingModel { ProgressView(value: downloadProgress.fraction); HStack { Text("Downloading"); Spacer(); Text("\(Int(downloadProgress.fraction * 100))%") }.font(.caption.weight(.medium)); HStack { Text(formatBytes(downloadProgress.bytesWritten)); Text("of"); Text(formatBytes(downloadProgress.totalBytes)); Spacer() }.font(.caption).foregroundStyle(.secondary) }
                            else if !modelAvailable { Button("Download Gemma 4", systemImage: "arrow.down.circle.fill") { downloadModel() }.buttonStyle(.borderedProminent).controlSize(.large) }
                        }
                    }
                    Button { moreWaysExpanded.toggle() } label: { HStack { VStack(alignment: .leading, spacing: 3) { Text("More ways to study").font(.headline); Text(moreWaysExpanded ? "Ask & Explain · uses your material · on device" : "Ask & Explain · tap to expand").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: moreWaysExpanded ? "chevron.down" : "chevron.right").foregroundStyle(.secondary) } }.buttonStyle(.plain)
                    if moreWaysExpanded {
                        VStack(spacing: 10) {
                            Picker("Mode", selection: $mode) { Text("Ask").tag(CreateMode.ask); Text("Explain").tag(CreateMode.explain) }.pickerStyle(.segmented)
                            if mode == .ask { TextField("Ask a question about your material", text: $askInput, axis: .vertical).lineLimit(2...5).textFieldStyle(.roundedBorder) }
                            else { TextField("What concept should be explained?", text: $explainInput, axis: .vertical).lineLimit(2...5).textFieldStyle(.roundedBorder) }
                        }
                    }
                    Button { generate() } label: { Label(isGenerating ? "Generating..." : mode == .flashcards ? "Create flashcards" : "Generate \(mode.rawValue)", systemImage: mode.icon).frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.large).disabled(!canGenerate || isGenerating)
                    if isGenerating { RecallCard { HStack(spacing: 12) { ProgressView(); VStack(alignment: .leading) { Text("Running on device").font(.headline); Text("Gemma 4 is generating your result.").font(.caption).foregroundStyle(.secondary) } } } }
                    if !generated.isEmpty { FlashcardResult(cards: generated, save: { if canSaveGenerated { deckName = deckName.isEmpty ? suggestedDeckName : deckName; selectedDeckID = selectedDeckID ?? decks.first?.id; showingSave = true } else { showingPaywall = true } }, dismiss: { generated = [] }) }
                    if let resultObject, generated.isEmpty { AdvancedResult(mode: mode, data: resultObject, dismiss: { self.resultObject = nil }) }
                    if !isGenerating { Text("🔒 Everything runs on device").font(.caption.weight(.semibold)).frame(maxWidth: .infinity).foregroundStyle(.secondary); Text("Nothing leaves your iPhone. Outputs may be inaccurate, so verify against your source.").font(.caption2).frame(maxWidth: .infinity).foregroundStyle(.tertiary).multilineTextAlignment(.center) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding()
            }
            .background(RecallTheme.canvas).navigationTitle("Create").navigationBarTitleDisplayMode(.inline)
            .task { modelAvailable = await modelStore.modelURL() != nil; await subscriptions.load() }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { handleImport($0) }
            .sheet(isPresented: $showingSave) { SaveDeckSheet(name: $deckName, selectedDeckID: $selectedDeckID, decks: decks) { saveGeneratedCards() } }
            .sheet(isPresented: $showingPaywall) { PaywallView(reason: "decks") }
            .alert("Couldn’t generate", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
        }
    }

    private var canGenerate: Bool { guard modelAvailable, !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }; if mode == .ask { return !askInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }; if mode == .explain { return !explainInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }; return true }
    private var canSaveGenerated: Bool { EntitlementRules.canCreateDeck(isPremium: subscriptions.isPremium, deckCount: decks.count) && (subscriptions.isPremium || generated.count <= EntitlementRules.freeCardLimitPerDeck) }
    private var suggestedDeckName: String { let words = sourceText.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ").prefix(5).joined(separator: " "); return words.isEmpty ? "New deck" : words.capitalized }
    private func downloadModel() { guard !isDownloadingModel else { return }; isDownloadingModel = true; downloadProgress = .init(fraction: 0, bytesWritten: 0, totalBytes: 0); Task { do { _ = try await modelStore.downloadModel { p in Task { @MainActor in downloadProgress = p } }; await MainActor.run { modelAvailable = true; isDownloadingModel = false } } catch { await MainActor.run { errorMessage = error.localizedDescription; isDownloadingModel = false } } } }
    private func handleImport(_ result: Result<[URL], Error>) { guard case .success(let urls) = result, let url = urls.first else { return }; do { sourceText = try importer.extractText(from: url); sourceName = url.deletingPathExtension().lastPathComponent; mode = .flashcards } catch { errorMessage = error.localizedDescription } }
    private func generate() { guard !isGenerating else { return }; isGenerating = true; generated = []; resultObject = nil; Task { @MainActor in do { if mode == .flashcards { generated = try await ai.generateFlashcards(from: sourceText) } else { let data = try await advancedAI.generateJSON(instruction: instruction, systemPrompt: prompt, source: sourceText); guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw AIServiceError.generationFailed("Gemma 4 returned an invalid result.") }; resultObject = object } } catch { errorMessage = error.localizedDescription }; isGenerating = false } }
    private var instruction: String { switch mode { case .guide: return "Create a concise study guide."; case .exam: return "Create a 10-question practice exam."; case .ask: return "Answer this question: \(askInput.trimmingCharacters(in: .whitespacesAndNewlines))"; case .explain: return "Explain this concept simply: \(explainInput.trimmingCharacters(in: .whitespacesAndNewlines))"; case .flashcards: return "Create flashcards." } }
    private var prompt: String { switch mode { case .guide: return "Return ONLY JSON: {\"title\":\"Study guide title\",\"overview\":\"2-4 sentence overview\",\"sections\":[{\"title\":\"Section\",\"summary\":\"Summary\",\"keyPoints\":[\"Point\"],\"keyTerms\":[{\"term\":\"Term\",\"definition\":\"Definition\"}]}],\"takeaways\":[\"Takeaway\"]}. Use 3-8 sections. Every factual claim must be supported by the source. Do not invent facts."; case .exam: return "Return ONLY JSON: {\"title\":\"Practice exam\",\"instructions\":\"Short instructions\",\"questions\":[{\"question\":\"Question\",\"type\":\"multiple_choice\",\"options\":[\"A\",\"B\",\"C\",\"D\"],\"correctIndex\":0,\"answer\":\"Answer\",\"explanation\":\"Explanation\"}]}. Create 10 questions, mixing multiple choice, true/false and short answer."; case .ask: return "Return ONLY JSON: {\"answer\":\"Concise answer\",\"citations\":[\"Supporting fact\"]}. Use only the supplied material. If absent, say you could not find it."; case .explain: return "Return ONLY JSON: {\"concept\":\"Concept\",\"explanation\":\"Simple explanation\",\"analogy\":\"Optional analogy\",\"keyPoints\":[\"Point\"]}. Use plain language and the supplied material."; case .flashcards: return "" } }
    private func saveGeneratedCards() {
        guard !generated.isEmpty else { showingSave = false; return }
        if let selectedDeckID, let deck = decks.first(where: { $0.id == selectedDeckID }) {
            generated.forEach { modelContext.insert(Flashcard(question: $0.question, answer: $0.answer, hint: $0.hint, tags: $0.tags, deck: deck)) }
        } else {
            guard EntitlementRules.canCreateDeck(isPremium: subscriptions.isPremium, deckCount: decks.count) else { showingSave = false; showingPaywall = true; return }
            let deck = Deck(name: deckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New deck" : deckName)
            modelContext.insert(deck)
            generated.forEach { modelContext.insert(Flashcard(question: $0.question, answer: $0.answer, hint: $0.hint, tags: $0.tags, deck: deck)) }
        }
        try? modelContext.save()
        generated = []; sourceText = ""; sourceName = ""; deckName = ""; selectedDeckID = nil; showingSave = false
    }
    private func formatBytes(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
}

private struct FlashcardResult: View { let cards: [GeneratedCard]; let save: () -> Void; let dismiss: () -> Void; var body: some View { VStack(alignment: .leading, spacing: 12) { HStack { Text("Ready to review").font(.title3.bold()); Spacer(); Text("\(cards.count) cards").font(.caption).foregroundStyle(.secondary) }; ForEach(cards) { card in RecallCard { VStack(alignment: .leading, spacing: 8) { Text(card.question).font(.headline); Divider(); Text(card.answer).foregroundStyle(.secondary); if !card.hint.isEmpty { Label(card.hint, systemImage: "lightbulb") .font(.caption).foregroundStyle(.secondary) }; if !card.tags.isEmpty { Text(card.tags).font(.caption2).foregroundStyle(.tertiary) } } } }; Button("Save to library", systemImage: "square.and.arrow.down.fill", action: save).buttonStyle(.borderedProminent).frame(maxWidth: .infinity); Button("Discard", role: .destructive, action: dismiss).frame(maxWidth: .infinity) } } }
private struct AdvancedResult: View { let mode: CreateMode; let data: [String: Any]; let dismiss: () -> Void; var body: some View { RecallCard { VStack(alignment: .leading, spacing: 12) { Text(mode.rawValue.uppercased()).font(.caption.weight(.bold)).foregroundStyle(RecallTheme.accent).tracking(1); content; Button("Done", action: dismiss).buttonStyle(.bordered).frame(maxWidth: .infinity) } } }; @ViewBuilder private var content: some View { switch mode { case .guide: GuideContent(data: data); case .exam: ExamContent(data: data); case .ask: Text(data["answer"] as? String ?? "No answer returned.").font(.body); case .explain: VStack(alignment: .leading, spacing: 8) { Text(data["concept"] as? String ?? "Explanation").font(.title3.bold()); Text(data["explanation"] as? String ?? ""); if let analogy = data["analogy"] as? String, !analogy.isEmpty { Text("Analogy").font(.headline); Text(analogy) }; ForEach((data["keyPoints"] as? [String]) ?? [], id: \.self) { Text("• \($0)") }; }; case .flashcards: EmptyView() } } }
private struct GuideContent: View { let data: [String: Any]; var body: some View { VStack(alignment: .leading, spacing: 10) { Text(data["title"] as? String ?? "Study guide").font(.title2.bold()); Text(data["overview"] as? String ?? "").foregroundStyle(.secondary); ForEach(Array(((data["sections"] as? [[String: Any]]) ?? []).enumerated()), id: \.offset) { _, section in VStack(alignment: .leading, spacing: 5) { Text(section["title"] as? String ?? "Section").font(.headline); Text(section["summary"] as? String ?? "").foregroundStyle(.secondary); ForEach((section["keyPoints"] as? [String]) ?? [], id: \.self) { Text("• \($0)") } } }; if let takeaways = data["takeaways"] as? [String], !takeaways.isEmpty { Text("Key takeaways").font(.headline); ForEach(takeaways, id: \.self) { Text("• \($0)") } } } } }
private struct ExamContent: View { let data: [String: Any]; @State private var revealed: Set<Int> = []; var body: some View { VStack(alignment: .leading, spacing: 12) { Text(data["title"] as? String ?? "Practice exam").font(.title2.bold()); Text(data["instructions"] as? String ?? "").foregroundStyle(.secondary); ForEach(Array(((data["questions"] as? [[String: Any]]) ?? []).enumerated()), id: \.offset) { index, q in VStack(alignment: .leading, spacing: 7) { Text("Question \(index + 1)").font(.caption.weight(.bold)).foregroundStyle(RecallTheme.accent); Text(q["question"] as? String ?? "").font(.headline); ForEach((q["options"] as? [String]) ?? [], id: \.self) { Text("• \($0)").foregroundStyle(.secondary) }; Button(revealed.contains(index) ? "Hide answer" : "Show answer") { if revealed.contains(index) { revealed.remove(index) } else { revealed.insert(index) } }; if revealed.contains(index) { Text("Answer: \(q["answer"] as? String ?? "")").padding(10).background(RecallTheme.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous)); if let explanation = q["explanation"] as? String { Text(explanation).font(.caption).foregroundStyle(.secondary) } } }.padding(.top, 8) } } } }
private struct SaveDeckSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var name: String
    @Binding var selectedDeckID: UUID?
    let decks: [Deck]
    let save: () -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("Save to") {
                    if decks.isEmpty {
                        Text("No decks yet. A new deck will be created.").foregroundStyle(.secondary)
                    } else {
                        Picker("Destination", selection: Binding(get: { selectedDeckID ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }, set: { value in
                            let emptyID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
                            selectedDeckID = value == emptyID ? nil : value
                        })) {
                            Text("New deck").tag(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
                            ForEach(decks) { deck in Text("\(deck.emoji)  \(deck.name)").tag(deck.id) }
                        }
                    }
                }
                if selectedDeckID == nil {
                    Section("New deck") {
                        TextField("Deck name", text: $name)
                    }
                }
                Section {
                    Text("Generated flashcards are saved locally and ready for spaced repetition.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Save cards")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
        .presentationDetents([.medium])
    }
}