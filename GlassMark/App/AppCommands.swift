import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var workspaceStore: WorkspaceStore
    @ObservedObject var documentStore: DocumentStore
    @ObservedObject var commandStore: CommandStore
    @ObservedObject var preferencesStore: PreferencesStore

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

        CommandGroup(after: .saveItem) {
            Divider()

            Button("Export as HTML…") {
                guard let document = documentStore.document else { return }
                MarkdownExporter.exportHTML(
                    documentStore.exportHTML(for: document),
                    suggestedName: baseName(for: document)
                )
            }
            .disabled(documentStore.document == nil)

            Button("Export as PDF…") {
                guard let document = documentStore.document else { return }
                MarkdownExporter.exportPDF(
                    html: documentStore.exportHTML(for: document),
                    baseURL: document.file.url.deletingLastPathComponent(),
                    suggestedName: baseName(for: document)
                )
            }
            .disabled(documentStore.document == nil)
        }

        CommandGroup(after: .toolbar) {
            Button("Quick Open…") {
                commandStore.presentQuickOpen()
            }
            .keyboardShortcut("p", modifiers: [.command])
            .disabled(workspaceStore.activeWorkspace == nil)

            Button(commandStore.isOutlineVisible ? "Hide Outline" : "Show Outline") {
                commandStore.toggleOutline()
            }
            .keyboardShortcut("0", modifiers: [.command, .option])
            .disabled(documentStore.document == nil)

            Toggle("Focus Mode", isOn: $preferencesStore.focusModeEnabled)
                .keyboardShortcut("f", modifiers: [.command, .control])
            Toggle("Typewriter Scrolling", isOn: $preferencesStore.typewriterModeEnabled)
        }

        CommandGroup(after: .sidebar) {
            Button("Refresh Workspace") {
                workspaceStore.refreshFileTree()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(workspaceStore.activeWorkspace == nil)
        }

        CommandMenu("Format") {
            Group {
                Button("Bold") { commandStore.run(.bold) }
                    .keyboardShortcut("b", modifiers: [.command])
                Button("Italic") { commandStore.run(.italic) }
                    .keyboardShortcut("i", modifiers: [.command])
                Button("Strikethrough") { commandStore.run(.strikethrough) }
                    .keyboardShortcut("x", modifiers: [.command, .shift])
                Button("Inline Code") { commandStore.run(.inlineCode) }
                    .keyboardShortcut("e", modifiers: [.command])
                Button("Insert Link") { commandStore.run(.link) }
                    .keyboardShortcut("k", modifiers: [.command])

                Divider()

                Button("Heading 1") { commandStore.run(.heading(level: 1)) }
                    .keyboardShortcut("1", modifiers: [.command, .control])
                Button("Heading 2") { commandStore.run(.heading(level: 2)) }
                    .keyboardShortcut("2", modifiers: [.command, .control])
                Button("Heading 3") { commandStore.run(.heading(level: 3)) }
                    .keyboardShortcut("3", modifiers: [.command, .control])

                Divider()

                Button("Bulleted List") { commandStore.run(.bulletList) }
                Button("Numbered List") { commandStore.run(.numberList) }
            }
            .disabled(documentStore.document == nil)
        }
    }

    private func baseName(for document: EditorDocument) -> String {
        document.file.url.deletingPathExtension().lastPathComponent
    }
}
