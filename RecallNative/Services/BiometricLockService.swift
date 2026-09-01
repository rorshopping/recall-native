import Foundation
import LocalAuthentication

@MainActor
final class BiometricLockService: ObservableObject {
    static let enabledKey = "biometricLockEnabled"
    static let gracePeriod: TimeInterval = 3

    @Published private(set) var available = false

    func refreshAvailability() {
        let context = LAContext()
        var error: NSError?
        available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func isEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
    }

    func confirmEnable() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Confirm Face ID to enable app lock"
            )
            if success { setEnabled(true) }
            return success
        } catch {
            return false
        }
    }

    func unlock() async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        context.localizedCancelTitle = "Cancel"

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Recall"
            )
        } catch {
            return false
        }
    }
}
