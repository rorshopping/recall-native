import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var page = 0

    private let pages: [(icon: String, title: String, body: String)] = [
        ("rectangle.stack.fill", "Remember what matters", "Turn your notes and documents into flashcards and review them with spaced repetition."),
        ("lock.shield.fill", "Private by design", "By default, your study material stays on your iPhone. On-device AI runs locally after the model is downloaded. Optional iCloud sync can be enabled in Settings."),
        ("checkmark.circle.fill", "Build your memory", "Start with a small deck, review what is due, and let Recall schedule the next review for you.")
    ]

    var body: some View {
        ZStack {
            RecallTheme.canvas.ignoresSafeArea()
            VStack(spacing: 28) {
                HStack {
                    if page > 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { page -= 1 }
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("onboarding.back")
                    } else {
                        Color.clear.frame(width: 1, height: 1)
                    }
                    Spacer()
                }
                .frame(minHeight: 24)

                Spacer()

                Image(systemName: pages[page].icon)
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(RecallTheme.accent)
                    .frame(width: 96, height: 96)
                    .background(RecallTheme.accent.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(pages[page].title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("onboarding.title")
                    Text(pages[page].body)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }

                HStack(spacing: 7) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? RecallTheme.accent : Color.secondary.opacity(0.22))
                            .frame(width: index == page ? 22 : 7, height: 7)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Onboarding page \(page + 1) of \(pages.count)")
                .accessibilityIdentifier("onboarding.progress")

                Spacer()

                Button {
                    if page == pages.count - 1 {
                        hasCompletedOnboarding = true
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) { page += 1 }
                    }
                } label: {
                    Text(page == pages.count - 1 ? "Get started" : "Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("onboarding.continue")

                if page < pages.count - 1 {
                    Button("Skip") { hasCompletedOnboarding = true }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("onboarding.skip")
                } else {
                    Text("You can change settings anytime.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 45)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        guard abs(horizontal) > abs(value.translation.height), abs(horizontal) > 70 else { return }
                        if horizontal < 0, page < pages.count - 1 {
                            withAnimation(.easeInOut(duration: 0.2)) { page += 1 }
                        } else if horizontal > 0, page > 0 {
                            withAnimation(.easeInOut(duration: 0.2)) { page -= 1 }
                        }
                    }
            )
            .accessibilityActions {
                if page > 0 {
                    Button("Previous page") {
                        withAnimation(.easeInOut(duration: 0.2)) { page -= 1 }
                    }
                }
                if page < pages.count - 1 {
                    Button("Next page") {
                        withAnimation(.easeInOut(duration: 0.2)) { page += 1 }
                    }
                }
            }
        }
        .interactiveDismissDisabled()
        .accessibilityElement(children: .contain)
    }
}
