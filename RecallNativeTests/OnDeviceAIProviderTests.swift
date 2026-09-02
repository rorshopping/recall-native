import Testing
@testable import RecallNative

struct OnDeviceAIProviderTests {
    @Test
    func appleProviderWinsWhenAvailable() {
        let withGemma = OnDeviceAIProvider.current(gemmaAvailable: true, appleAvailable: true)
        let withoutGemma = OnDeviceAIProvider.current(gemmaAvailable: false, appleAvailable: true)
        #expect(withGemma.displayName == "Apple on-device model")
        #expect(withoutGemma.displayName == "Apple on-device model")
    }

    @Test
    func unsupportedAppleLocaleFallsBackToGemma() {
        let provider = OnDeviceAIProvider.current(
            gemmaAvailable: true,
            appleAvailable: true,
            appleSupportsLocale: false
        )
        #expect(provider == .gemma)
    }

    @Test
    func unsupportedAppleLocaleIsUnavailableWithoutGemma() {
        let provider = OnDeviceAIProvider.current(
            gemmaAvailable: false,
            appleAvailable: true,
            appleSupportsLocale: false
        )
        #expect(provider == .unavailable)
    }

    @Test
    func gemmaIsTheFallbackWhenAppleIsUnavailable() {
        #expect(OnDeviceAIProvider.current(gemmaAvailable: true, appleAvailable: false).displayName == "Gemma 4 E2B")
    }

    @Test
    func unavailableWhenNeitherBackendExists() {
        #expect(OnDeviceAIProvider.current(gemmaAvailable: false, appleAvailable: false).displayName == "On-device AI unavailable")
    }

    @Test
    func providerCopyExplainsFallback() {
        #expect(OnDeviceAIProvider.apple.detail.contains("Gemma 4"))
        #expect(OnDeviceAIProvider.gemma.displayName == "Gemma 4 E2B")
    }
}
