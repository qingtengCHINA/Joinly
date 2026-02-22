import SwiftUI

@main
struct JoinlyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1120, minHeight: 700)
        }
        .commands {
            JoinlyCommands()
        }

        Window("About Joinly", id: "about") {
            AboutView()
                .frame(width: 380, height: 420)
        }
        .windowResizability(.contentSize)

        Window("Settings", id: "settings") {
            SettingsView()
                .frame(width: 620, height: 560)
        }
        .windowResizability(.contentSize)
    }
}

struct JoinlyCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Joinly") {
                openWindow(id: "about")
            }
        }
        
        CommandGroup(replacing: .appSettings) {
            Button("Settings") {
                openWindow(id: "settings")
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

