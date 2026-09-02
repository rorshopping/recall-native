import Foundation

/// Describes the preferred on-device generation backend without coupling the UI to a specific model implementation.
enum OnDeviceAIProvider: Sendable, Equatable {
    case apple
    case gemma
    case unavailable

    var displayName: String {
        switch self {
        case .apple: return "Apple on-device model"
        case .gemma: return "Gemma 4 E2B"
        case .unavailable: return "On-device AI unavailable"
        }
    }

    var detail: String {
        switch self {
        case .apple: return "Using Apple's on-device model. Gemma 4 is the automatic fallback."
        case .gemma: return "Using Gemma 4 E2B locally."
        case .unavailable: return "Download Gemma 4 to enable on-device generation."
        }
    }

    var isAvailable: Bool {
        self != .unavailable
    }

    var systemImage: String {
        switch self {
        case .apple: return "apple.logo"
        case .gemma: return "cpu"
        case .unavailable: return "exclamationmark.triangle"
        }
    }

    /// Explains why Apple's model is not currently active. This is intentionally separate
    /// from provider selection so the app can distinguish an unsupported device from a model
    /// that is still downloading or Apple Intelligence being disabled.
    static var appleAvailabilityDetail: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return "Apple's on-device model is ready."
            case .unavailable(.modelNotReady):
                return "Apple's model is not ready yet, so Gemma 4 is used as the fallback."
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Apple Intelligence is turned off, so Gemma 4 is used as the local fallback."
            case .unavailable(.deviceNotEligible):
                return "This device can't use Apple's on-device model, so Gemma 4 is used locally."
            @unknown default:
                return "Apple's on-device model is currently unavailable, so Gemma 4 is used as the fallback."
            }
        }
        #endif
        return "Apple's on-device model requires a supported system; Gemma 4 is the local fallback."
    }

    /// Returns the current provider. `appleAvailable` is injectable for deterministic tests.
    static func current(gemmaAvailable: Bool, appleAvailable: Bool? = nil) -> OnDeviceAIProvider {
        #if canImport(FoundationModels)
        if let appleAvailable {
            return appleAvailable ? .apple : (gemmaAvailable ? .gemma : .unavailable)
        }
        if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable {
            return .apple
        }
        #else
        if let appleAvailable {
            return appleAvailable ? .apple : (gemmaAvailable ? .gemma : .unavailable)
        }
        #endif
        return gemmaAvailable ? .gemma : .unavailable
    }
}
