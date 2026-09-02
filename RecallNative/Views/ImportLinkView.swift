import SwiftUI
import SwiftData

struct ImportLinkView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let url: URL
    @State private var phase: Phase = .confirm
    @State private var error = ""
    @State private var importedName = ""
    @State private var importedCount = 0
    @State private var importedDeck: Deck?
    @State private var showingImportedDeck = false

    enum Phase { case confirm, loading, done, failed }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                switch phase {
                case .confirm:
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 42))
                        .foregroundStyle(RecallTheme.accent)
                    Text("Import this deck?")
                        .font(.title2.bold())
                    Text(sourceDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 520)
                    Button("Import deck") { Task { await importDeck() } }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("import.confirm")
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("import.cancel")
                case .loading:
                    ProgressView().controlSize(.large)
                    Text("Importing deck…")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("import.loading")
                case .done:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.green)
                    Text("Deck added")
                        .font(.title2.bold())
                    Text("\(importedName) · \(importedCount) card\(importedCount == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                    Button("Open deck") { showingImportedDeck = importedDeck != nil }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("import.openDeck")
                    Button("Done") { dismiss() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("import.done")
                case .failed:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(.orange)
                    Text("Could not import")
                        .font(.title2.bold())
                    Text(error)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("import.errorDone")
                }
            }
            .padding(28)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingImportedDeck) {
                if let importedDeck {
                    NavigationStack { DeckDetailView(deck: importedDeck) }
                }
            }
        }
    }

    private var sourceDescription: String {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if items.contains(where: { $0.name == "data" }) {
            return "A link is asking Recall to add a deck with embedded data.\n\nOnly continue if you trust the source."
        }
        if let remote = items.first(where: { $0.name == "url" })?.value,
           let remoteURL = URL(string: remote) {
            return "A link is asking Recall to add a deck from:\n\n\(remoteURL.absoluteString)\n\nOnly continue if you trust its source."
        }
        return "The link does not contain a supported deck source."
    }

    @MainActor
    private func importDeck() async {
        phase = .loading
        do {
            let data = try await loadData()
            let deck = try DeckImportService.add(data, to: modelContext)
            importedDeck = deck
            importedName = deck.name
            importedCount = deck.cards.count
            phase = .done
        } catch {
            self.error = error.localizedDescription
            phase = .failed
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
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ImportError.httpFailure(http.statusCode)
        }
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
