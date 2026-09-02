import SwiftUI

/// Lightweight native celebration matching the original review success feedback.
/// Increment `fire` to emit a fresh burst without retaining particle state in the caller.
struct ConfettiView: View {
    let fire: Int
    @State private var burstID = UUID()

    var body: some View {
        ZStack {
            if fire > 0 {
                ForEach(0..<28, id: \ .self) { index in
                    ConfettiParticle(index: index, seed: burstID)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: fire) { _, newValue in
            guard newValue > 0 else { return }
            burstID = UUID()
        }
    }
}

private struct ConfettiParticle: View {
    let index: Int
    let seed: UUID
    @State private var progress = 0.0

    private var angle: Double {
        let values = seed.uuid.0
        let raw = Int(values) + index * 47
        return Double(abs(raw % 360))
    }

    private var distance: Double {
        let values = seed.uuid.1
        return 90 + Double(abs(Int(values) + index * 23) % 150)
    }

    private var size: CGFloat {
        let values = seed.uuid.2
        return CGFloat(5 + abs(Int(values) + index * 11) % 7)
    }

    private var rotation: Double {
        let values = seed.uuid.3
        return Double(Int(values) + index * 31) * 8
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(.primary.opacity(0.82))
            .frame(width: size, height: size * 0.62)
            .rotationEffect(.degrees(rotation * progress))
            .offset(
                x: cos(angle * .pi / 180) * distance * progress,
                y: sin(angle * .pi / 180) * distance * progress + 120 * progress * progress
            )
            .opacity(1 - progress)
            .task(id: seed) {
                progress = 0
                withAnimation(.easeOut(duration: 0.9)) {
                    progress = 1
                }
            }
    }
}

private extension UUID {
    var uuid: (UInt8, UInt8, UInt8, UInt8) {
        withUnsafeBytes { bytes in
            (
                bytes[0],
                bytes[1],
                bytes[2],
                bytes[3]
            )
        }
    }
}
