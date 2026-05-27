import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var documentStore: DocumentStore
    @EnvironmentObject private var preferencesStore: PreferencesStore
    @EnvironmentObject private var commandStore: CommandStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 420)
        } detail: {
            DetailWorkspaceView()
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    guard let file = workspaceStore.createMarkdownFile(),
                          let workspace = workspaceStore.activeWorkspace else { return }

                    documentStore.open(file, workspace: workspace)
                } label: {
                    Label("New Markdown File", systemImage: "doc.badge.plus")
                }
                .disabled(workspaceStore.activeWorkspace == nil)

                Button {
                    workspaceStore.refreshFileTree()
                } label: {
                    Label("Refresh Workspace", systemImage: "arrow.clockwise")
                }
                .disabled(workspaceStore.activeWorkspace == nil)

                Button {
                    commandStore.presentQuickOpen()
                } label: {
                    Label("Quick Open", systemImage: "magnifyingglass")
                }
                .help("Quick Open (⌘P)")
                .disabled(workspaceStore.activeWorkspace == nil)

                Picker("View Mode", selection: $preferencesStore.viewMode) {
                    ForEach(ViewMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Button("Save") {
                    documentStore.save()
                }
                .disabled(!documentStore.canSave)
            }
        }
        .alert("Workspace Error", isPresented: workspaceErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(workspaceStore.errorMessage ?? "Unknown workspace error.")
        }
        .alert("Document Error", isPresented: documentErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(documentStore.errorMessage ?? "Unknown document error.")
        }
        .onChange(of: workspaceStore.activeWorkspace?.id) {
            documentStore.activate(workspace: workspaceStore.activeWorkspace)
        }
        .sheet(isPresented: $commandStore.isQuickOpenPresented) {
            QuickOpenView(files: workspaceStore.fileTree) { file in
                guard let workspace = workspaceStore.activeWorkspace else { return }
                documentStore.open(file, workspace: workspace)
            }
        }
    }

    private var workspaceErrorBinding: Binding<Bool> {
        Binding(
            get: { workspaceStore.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    workspaceStore.clearError()
                }
            }
        )
    }

    private var documentErrorBinding: Binding<Bool> {
        Binding(
            get: { documentStore.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    documentStore.clearError()
                }
            }
        )
    }
}

private struct DetailWorkspaceView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var documentStore: DocumentStore
    @EnvironmentObject private var preferencesStore: PreferencesStore

    var body: some View {
        Group {
            if workspaceStore.activeWorkspace == nil {
                WorkspaceWelcomeView()
            } else {
                VStack(spacing: 0) {
                    if !documentStore.openDocuments.isEmpty {
                        DocumentTabBarView()
                        Divider()
                    }

                    if documentStore.document == nil {
                        EmptyFileSelectionView()
                    } else {
                        EditorPreviewContainerView()
                    }
                }
            }
        }
    }
}

private struct DocumentTabBarView: View {
    @EnvironmentObject private var documentStore: DocumentStore
    @State private var pendingCloseDocument: EditorDocument?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(documentStore.openDocuments) { document in
                    DocumentTabView(
                        document: document,
                        isSelected: documentStore.document?.id == document.id,
                        onSelect: {
                            documentStore.selectDocument(id: document.id)
                        },
                        onClose: {
                            if document.isDirty {
                                pendingCloseDocument = document
                            } else {
                                documentStore.closeDocument(id: document.id)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .scrollIndicators(.hidden)
        .background(.bar)
        .alert("Close Unsaved File?", isPresented: pendingCloseBinding, presenting: pendingCloseDocument) { document in
            Button("Close Without Saving", role: .destructive) {
                documentStore.closeDocument(id: document.id)
                pendingCloseDocument = nil
            }

            Button("Cancel", role: .cancel) {
                pendingCloseDocument = nil
            }
        } message: { document in
            Text("\(document.file.name) has unsaved changes.")
        }
    }

    private var pendingCloseBinding: Binding<Bool> {
        Binding(
            get: { pendingCloseDocument != nil },
            set: { isPresented in
                if !isPresented {
                    pendingCloseDocument = nil
                }
            }
        )
    }
}

private struct DocumentTabView: View {
    let document: EditorDocument
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(document.file.name)
                .font(.callout)
                .lineLimit(1)

            if document.isDirty {
                Circle()
                    .fill(.orange)
                    .frame(width: 7, height: 7)
                    .help("Unsaved changes")
            }

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: 220)
        .background(isSelected ? Color.primary.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.primary.opacity(0.16) : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture(perform: onSelect)
    }
}

private struct WorkspaceWelcomeView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore

    var body: some View {
        ContentUnavailableView {
            Label("Open a Workspace", systemImage: "folder")
        } description: {
            Text("Choose a local folder containing Markdown files.")
        } actions: {
            Button("Open Workspace…") {
                workspaceStore.presentWorkspacePicker()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }
    }
}

private struct EmptyFileSelectionView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Select a File", systemImage: "doc.text")
        } description: {
            Text("Choose a Markdown file from the sidebar to start editing.")
        }
    }
}

private struct EditorPreviewContainerView: View {
    @EnvironmentObject private var preferencesStore: PreferencesStore

    var body: some View {
        switch preferencesStore.viewMode {
        case .editorOnly:
            EditorView()
        case .split:
            HSplitView {
                EditorView()
                    .frame(minWidth: 360)
                PreviewView()
                    .frame(minWidth: 360)
            }
        case .previewOnly:
            PreviewView()
        }
    }
}
