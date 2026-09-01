import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Today", systemImage: "sparkles") }
            DecksView()
                .tabItem { Label("Library", systemImage: "rectangle.stack") }
            CreateView()
                .tabItem { Label("Create", systemImage: "plus.circle.fill") }
            ReviewView()
                .tabItem { Label("Review", systemImage: "brain.head.profile") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(RecallTheme.accent)
    }
}
