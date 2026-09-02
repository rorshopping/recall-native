import Testing
@testable import RecallNative

struct OnDeviceAIProviderTests {
    @Test
    func appleProviderWinsWhenAvailable() {
        #expect(OnDeviceAIProvider.current(gemmaAvailable: true, appleAvailable: true) == .apple)
        #expect(OnDeviceAIProvider.current(gemmaAvailable: false, appleAvailable: true) == .apple)
    }

    @Test
    func gemmaIsTheFallbackWhenAppleIsUnavailable() {
        #expect(OnDeviceAIProvider.current(gemmaAvailable: true, appleAvailable: false) == .gemma)
    }

    @Test
    func unavailableWhenNeitherBackendExists() {
        #expect(OnDeviceAIProvider.current(gemmaAvailable: false, appleAvailable: false) == .unavailable)
    }

    @Test
    func providerCopyExplainsFallback() {
        #expect(OnDeviceAIProvider.apple.detail.contains("Gemma 4"))
        #expect(OnDeviceAIProvider.gemma.displayName == "Gemma 4 E2B")
    }
}
