import SwiftUI

enum RecallTab: Hashable {
    case decks, create, stats, settings
}

struct RootView: View {
    @State private var selectedTab: RecallTab = .decks
    @State private var importURL: URL?
    @State private var showingDesignLab = false
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("designTheme") private var designTheme = "recall"
    @AppStorage("designLabTaps") private var designLabTaps = 0

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        GeometryReader { proxy in
            TabView(selection: $selectedTab) {
                DecksView()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .tabItem { Label("Decks", systemImage: "tray.full") }
                    .tag(RecallTab.decks)
                CreateView()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .tabItem { Label("Create", systemImage: "sparkles") }
                    .tag(RecallTab.create)
                StatsView()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .tabItem { Label("Stats", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(RecallTab.stats)
                SettingsView()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(RecallTab.settings)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .tint(RecallTheme.accent)
        .preferredColorScheme(colorScheme)
        .onOpenURL { url in
            guard ["recall", "recall-flashcards"].contains(url.scheme?.lowercased()), url.host?.lowercased() == "import" else { return }
            importURL = url
        }
        .sheet(item: $importURL) { url in ImportLinkView(url: url) }
        .sheet(isPresented: $showingDesignLab) { DesignLabView() }
        .simultaneousGesture(LongPressGesture(minimumDuration: 1.2).onEnded { _ in
            designLabTaps += 1
            if designLabTaps >= 7 {
                designLabTaps = 0
                showingDesignLab = true
            }
        })
    }
}
