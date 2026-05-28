import SwiftUI

@main
struct GlassMarkApp: App {
    @StateObject private var workspaceStore = WorkspaceStore()
    @StateObject private var documentStore = DocumentStore()
    @StateObject private var preferencesStore = PreferencesStore()
    @StateObject private var commandStore = CommandStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workspaceStore)
                .environmentObject(documentStore)
                .environmentObject(preferencesStore)
                .environmentObject(commandStore)
                .frame(minWidth: 980, minHeight: 640)
                .preferredColorScheme(preferencesStore.resolvedColorScheme)
                .task {
                    workspaceStore.restoreKnownWorkspaces()
                }
        }
        .commands {
            AppCommands(
                workspaceStore: workspaceStore,
                documentStore: documentStore,
                commandStore: commandStore,
                preferencesStore: preferencesStore
            )
        }

        Settings {
            SettingsView()
                .environmentObject(preferencesStore)
        }
    }
}
