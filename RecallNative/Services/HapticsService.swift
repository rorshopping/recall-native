import UIKit

enum HapticsService {
    static func grade(_ grade: Int) {
        let enabled = UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
        guard enabled else { return }
        switch grade {
        case 0: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case 1: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case 2: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case 3: UINotificationFeedbackGenerator().notificationOccurred(.success)
        default: break
        }
    }
}
