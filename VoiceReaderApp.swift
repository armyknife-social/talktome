import SwiftUI
import SwiftData

@main
struct VoiceReaderApp: App {
    @State private var playerViewModel = PlayerViewModel()
    @AppStorage("appTheme") private var appTheme: String = "system"

    var body: some Scene {
        WindowGroup {
            ContentView(playerViewModel: playerViewModel)
                .preferredColorScheme(colorScheme)
                .onAppear {
                    playerViewModel.loadDefaults()
                }
        }
        .modelContainer(for: [
            Document.self,
            Bookmark.self,
            Highlight.self,
            ReadingProgress.self
        ])
    }

    private var colorScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

// MARK: - Main Content View with Tab Bar and Mini Player

struct ContentView: View {
    @Bindable var playerViewModel: PlayerViewModel
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                LibraryView(playerViewModel: playerViewModel)
                    .tabItem {
                        Label("Library", systemImage: "books.vertical")
                    }
                    .tag(0)

                SettingsView(playerViewModel: playerViewModel)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(1)
            }

            // Mini player overlay above tab bar
            VStack {
                Spacer()
                MiniPlayerView(playerViewModel: playerViewModel)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 49) // Tab bar height
            }
        }
    }
}
