import SwiftUI

struct OnDeviceAISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isInstalled = false
    @State private var isDownloading = false
    @State private var progress: ModelDownloadProgress?
    @State private var errorMessage: String?
    @State private var showingRemoveConfirmation = false

    private let modelSize = "2.59 GB"

    var body: some View {
        NavigationStack {
            List {
                Section("Gemma 4 E2B") {
                    HStack {
                        Label(isInstalled ? "Ready on this iPhone" : "Not downloaded", systemImage: isInstalled ? "checkmark.circle.fill" : "arrow.down.circle")
                        Spacer()
                        Text(modelSize).font(.caption).foregroundStyle(.secondary)
                    }

                    if isDownloading {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: progress?.fraction ?? 0)
                            HStack {
                                Text("Downloading…")
                                Spacer()
                                Text(progressText).monospacedDigit().foregroundStyle(.secondary)
                            }.font(.caption)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Downloading Gemma 4, \(progressText)")

                        Button("Cancel download", systemImage: "xmark.circle", role: .destructive) {
                            Task { await LiteRTModelStore.shared.cancelDownload() }
                        }
                        .accessibilityHint("Stops the download and removes the partial model file.")
                    } else if !isInstalled {
                        Button("Download Gemma 4", systemImage: "arrow.down.circle.fill") {
                            startDownload()
                        }
                        Text("The model is downloaded once and then runs entirely on-device. A Wi-Fi connection is recommended. The download is about \(modelSize).")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Flashcard generation runs locally with LiteRT-LM. Your study material is not sent to a cloud AI service by Recall.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Remove downloaded model", systemImage: "trash", role: .destructive) {
                            showingRemoveConfirmation = true
                        }
                    }
                }

                Section("Privacy") {
                    Label("On-device inference", systemImage: "iphone")
                    Text("After download, Gemma processes your study material locally on your iPhone. No API key is required.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("On-device AI")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await refresh() }
            .confirmationDialog("Remove Gemma 4?", isPresented: $showingRemoveConfirmation, titleVisibility: .visible) {
                Button("Remove Model", role: .destructive) {
                    Task { await LiteRTModelStore.shared.deleteDownloadedModel(); await refresh() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This frees about \(modelSize) of storage. You can download the model again later.")
            }
            .alert("Model download failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") {}
            } message: { Text(errorMessage ?? "") }
        }
    }

    private var progressText: String {
        guard let progress else { return "Downloading in background" }
        let percent = Int((progress.fraction * 100).rounded())
        guard progress.totalBytes > 0 else { return "\(percent)%" }
        return "\(percent)% · \(formatBytes(progress.bytesWritten)) / \(formatBytes(progress.totalBytes))"
    }

    private func refresh() async {
        let store = LiteRTModelStore.shared
        let installed = await store.modelURL() != nil
        let hasActive = await store.hasActiveDownload()
        let downloading = !installed && hasActive
        await MainActor.run {
            isInstalled = installed
            isDownloading = downloading
        }
        if downloading { attachToDownload() }
    }

    private func startDownload() {
        guard !isDownloading else { return }
        isDownloading = true
        progress = nil
        errorMessage = nil
        attachToDownload()
    }

    private func attachToDownload() {
        Task {
            do {
                _ = try await LiteRTModelStore.shared.downloadModel { update in
                    Task { @MainActor in progress = update }
                }
                await MainActor.run {
                    isDownloading = false
                    isInstalled = true
                    progress = ModelDownloadProgress(fraction: 1, bytesWritten: 0, totalBytes: 0)
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
