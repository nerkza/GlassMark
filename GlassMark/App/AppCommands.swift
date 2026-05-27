import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var workspaceStore: WorkspaceStore
    @ObservedObject var documentStore: DocumentStore
    @ObservedObject var commandStore: CommandStore

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Markdown File") {
                guard let file = workspaceStore.createMarkdownFile(),
                      let workspace = workspaceStore.activeWorkspace else { return }

                documentStore.open(file, workspace: workspace)
            }
            .keyboardShortcut("n", modifiers: [.command])
            .disabled(workspaceStore.activeWorkspace == nil)

            Button("Open Workspace…") {
                workspaceStore.presentWorkspacePicker()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }

        CommandGroup(after: .toolbar) {
            Button("Quick Open…") {
                commandStore.presentQuickOpen()
            }
            .keyboardShortcut("p", modifiers: [.command])
            .disabled(workspaceStore.activeWorkspace == nil)
        }

        CommandGroup(after: .saveItem) {
            Button("Save") {
                documentStore.save()
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(!documentStore.canSave)
        }

        CommandGroup(after: .sidebar) {
            Button("Refresh Workspace") {
                workspaceStore.refreshFileTree()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(workspaceStore.activeWorkspace == nil)
        }
    }
}
