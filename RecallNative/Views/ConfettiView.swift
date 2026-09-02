import SwiftUI

/// Lightweight native celebration matching the original review success feedback.
/// Increment `fire` to emit a fresh burst without retaining particle state in the caller.
struct ConfettiView: View {
    let fire: Int
    @State private var burstID = UUID()

    var body: some View {
        ZStack {
            if fire > 0 {
                ForEach(0..<28, id: \.self) { index in
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
        Double(abs(Int(seed.uuid.0) + index * 47) % 360)
    }

    private var distance: Double {
        90 + Double(abs(Int(seed.uuid.1) + index * 23) % 150)
    }

    private var size: CGFloat {
        CGFloat(5 + abs(Int(seed.uuid.2) + index * 11) % 7)
    }

    private var rotation: Double {
        Double(Int(seed.uuid.3) + index * 31) * 8
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
