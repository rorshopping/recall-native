import SwiftUI

struct OnDeviceAISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isInstalled = false
    @State private var isDownloading = false
    @State private var progress: ModelDownloadProgress?
    @State private var errorMessage: String?
    @State private var showingRemoveConfirmation = false

    private let modelSize = "2.59 GB"

    private var provider: OnDeviceAIProvider {
        OnDeviceAIProvider.current(gemmaAvailable: isInstalled)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Active AI") {
                    Label(provider.displayName, systemImage: provider.systemImage)
                    Text(provider.detail).font(.subheadline).foregroundStyle(.secondary)
                    if provider.isAvailable {
                        Label("Inference stays on this iPhone", systemImage: "iphone")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Gemma 4 fallback") {
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
                            Task { await LiteRTModelStore.shared.cancelDownload(); await refresh() }
                        }
                        .accessibilityHint("Stops the download and removes the partial model file.")
                    } else if !isInstalled {
                        Button("Download Gemma 4", systemImage: "arrow.down.circle.fill") {
                            startDownload()
                        }
                        Text(provider == .apple ? "Optional on this device. Keeping Gemma installed provides a local fallback if Apple's model becomes unavailable." : "The model is downloaded once and then runs entirely on-device. A Wi-Fi connection is recommended. The download is about \(modelSize).")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Gemma 4 is installed as the local compatibility fallback. Flashcard and advanced generation can use it automatically if Apple's model is unavailable or generation fails.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Remove downloaded model", systemImage: "trash", role: .destructive) {
                            showingRemoveConfirmation = true
                        }
                    }
                }

                Section("Privacy") {
                    Label("On-device inference", systemImage: "iphone")
                    Text("Recall does not send study material to a cloud AI service for generation. When Apple’s on-device model is available it is preferred; otherwise Recall can use the locally installed Gemma fallback.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("How fallback works") {
                    Label("1. Apple on-device model", systemImage: "sparkles")
                    Label("2. Gemma 4 E2B", systemImage: "cpu")
                    Text("Recall automatically tries the Apple model first on supported systems. If it is unavailable or generation fails, Gemma is used when installed. No manual model switching is required.")
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
                Text("This frees about \(modelSize) of storage. If Apple’s on-device model is unavailable, Recall will no longer have a Gemma fallback until you download it again.")
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
