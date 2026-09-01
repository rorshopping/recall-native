import SwiftUI
import SwiftData

struct ImportLinkView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let url: URL
    @State private var state: State = .confirm
    @State private var error = ""
    @State private var importedName = ""
    @State private var importedCount = 0

    enum State { case confirm, loading, done, failed }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                switch state {
                case .confirm:
                    Image(systemName: "square.and.arrow.down").font(.system(size: 42)).foregroundStyle(RecallTheme.accent)
                    Text("Import this deck?").font(.title2.bold())
                    Text(sourceDescription).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Import deck") { Task { await importDeck() } }.buttonStyle(.borderedProminent).controlSize(.large)
                    Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                case .loading:
                    ProgressView().controlSize(.large)
                    Text("Importing deck…").foregroundStyle(.secondary)
                case .done:
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 52)).foregroundStyle(.green)
                    Text("Deck added").font(.title2.bold())
                    Text("\(importedName) · \(importedCount) card\(importedCount == 1 ? "" : "s")").foregroundStyle(.secondary)
                    Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
                case .failed:
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 46)).foregroundStyle(.orange)
                    Text("Could not import").font(.title2.bold())
                    Text(error).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
                }
            }
            .padding(28)
            .frame(maxWidth: 560).frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var sourceDescription: String {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let data = items.first(where: { $0.name == "data" })?.value { return "A deck is being shared with Recall.\n\n\(data.prefix(180))\(data.count > 180 ? "…" : "")" }
        if let remote = items.first(where: { $0.name == "url" })?.value { return "A deck is being imported from:\n\n\(remote)" }
        return "The link does not contain a supported deck source."
    }

    @MainActor
    private func importDeck() async {
        state = .loading
        do {
            let data = try await loadData()
            let parsed = try DeckImportService.parse(data)
            let deck = Deck(name: parsed.name, emoji: "📚")
            modelContext.insert(deck)
            for card in parsed.cards {
                let item = Flashcard(
                    question: card.front.trimmingCharacters(in: .whitespacesAndNewlines),
                    answer: card.back.trimmingCharacters(in: .whitespacesAndNewlines),
                    hint: card.hint ?? "",
                    tags: card.tags ?? "",
                    deck: deck
                )
                modelContext.insert(item)
            }
            try modelContext.save()
            importedName = parsed.name
            importedCount = parsed.cards.count
            state = .done
        } catch {
            error = error.localizedDescription
            state = .failed
        }
    }

    private func loadData() async throws -> Data {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let encoded = items.first(where: { $0.name == "data" })?.value {
            guard let data = encoded.data(using: .utf8) else { throw ImportError.invalidData }
            guard data.count <= 2 * 1024 * 1024 else { throw ImportError.tooLarge }
            return data
        }
        guard let remote = items.first(where: { $0.name == "url" })?.value,
              let remoteURL = URL(string: remote),
              ["http", "https"].contains(remoteURL.scheme?.lowercased())
        else { throw ImportError.invalidData }
        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) { throw ImportError.httpFailure(http.statusCode) }
        guard data.count <= 2 * 1024 * 1024 else { throw ImportError.tooLarge }
        return data
    }

    enum ImportError: LocalizedError {
        case invalidData, tooLarge, httpFailure(Int)
        var errorDescription: String? {
            switch self {
            case .invalidData: return "The link does not contain valid deck data."
            case .tooLarge: return "Deck file is too large. Maximum size is 2 MB."
            case .httpFailure(let code): return "Could not fetch deck (HTTP \(code))."
            }
        }
    }
}
