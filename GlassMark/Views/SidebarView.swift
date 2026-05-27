import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var documentStore: DocumentStore
    @State private var filePendingRename: WorkspaceFile?
    @State private var renameText = ""
    @State private var filePendingTrash: WorkspaceFile?
    @State private var expandedFileIDs: Set<WorkspaceFile.ID> = []
    @State private var fileClipboard: FileClipboardItem?

    var body: some View {
        HStack(spacing: 0) {
            WorkspaceRailView()

            Divider()

            VStack(spacing: 0) {
                WorkspaceSwitcherView()
                    .padding()

                Divider()

                if workspaceStore.activeWorkspace == nil {
                    Spacer()
                    Text("No workspace open")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else if workspaceStore.fileTree.isEmpty {
                    ContentUnavailableView("No Markdown Files", systemImage: "doc.text.magnifyingglass")
                } else {
                    FileTreeView(
                        files: workspaceStore.fileTree,
                        selectedFileID: documentStore.document?.file.id,
                        expandedFileIDs: $expandedFileIDs,
                        onSelect: { file in
                            guard let workspace = workspaceStore.activeWorkspace else { return }
                            documentStore.open(file, workspace: workspace)
                        },
                        onNewMarkdownFile: { file in
                            guard let newFile = workspaceStore.createMarkdownFile(nextTo: file),
                                  let workspace = workspaceStore.activeWorkspace else { return }

                            documentStore.open(newFile, workspace: workspace)
                        },
                        onNewFolder: { file in
                            workspaceStore.createFolder(nextTo: file)
                        },
                        onRename: { file in
                            filePendingRename = file
                            renameText = file.name
                        },
                        onCut: { file in
                            fileClipboard = FileClipboardItem(file: file, operation: .cut)
                        },
                        onCopy: { file in
                            fileClipboard = FileClipboardItem(file: file, operation: .copy)
                        },
                        onPaste: { target in
                            pasteClipboard(to: target)
                        },
                        canPaste: fileClipboard != nil,
                        onDuplicate: { file in
                            workspaceStore.duplicate(file)
                        },
                        onRevealInFinder: { file in
                            workspaceStore.revealInFinder(file)
                        },
                        onMoveToTrash: { file in
                            filePendingTrash = file
                        },
                        onMove: { source, target in
                            guard let workspace = workspaceStore.activeWorkspace,
                                  let newURL = workspaceStore.move(source, to: target) else { return }

                            documentStore.moveOpenDocuments(from: source, to: newURL, rootURL: workspace.rootURL)
                        }
                    )
                }
            }
        }
        .alert("Rename", isPresented: renameBinding, presenting: filePendingRename) { file in
            TextField("Name", text: $renameText)

            Button("Rename") {
                workspaceStore.rename(file, to: renameText)
                filePendingRename = nil
            }

            Button("Cancel", role: .cancel) {
                filePendingRename = nil
            }
        } message: { file in
            Text("Enter a new name for \(file.name).")
        }
        .alert("Move to Trash?", isPresented: trashBinding, presenting: filePendingTrash) { file in
            Button("Move to Trash", role: .destructive) {
                documentStore.closeDocuments(for: file)
                workspaceStore.moveToTrash(file)
                filePendingTrash = nil
            }

            Button("Cancel", role: .cancel) {
                filePendingTrash = nil
            }
        } message: { file in
            Text("This will move \(file.name) to the Trash.")
        }
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { filePendingRename != nil },
            set: { isPresented in
                if !isPresented {
                    filePendingRename = nil
                }
            }
        )
    }

    private var trashBinding: Binding<Bool> {
        Binding(
            get: { filePendingTrash != nil },
            set: { isPresented in
                if !isPresented {
                    filePendingTrash = nil
                }
            }
        )
    }

    private func pasteClipboard(to target: WorkspaceFile) {
        guard let fileClipboard else { return }

        switch fileClipboard.operation {
        case .copy:
            workspaceStore.copy(fileClipboard.file, to: target)
        case .cut:
            guard let workspace = workspaceStore.activeWorkspace,
                  let newURL = workspaceStore.move(fileClipboard.file, to: target) else { return }

            documentStore.moveOpenDocuments(from: fileClipboard.file, to: newURL, rootURL: workspace.rootURL)
            self.fileClipboard = nil
        }
    }
}

private struct FileClipboardItem {
    let file: WorkspaceFile
    let operation: FileClipboardOperation
}

private enum FileClipboardOperation {
    case cut
    case copy
}

private struct WorkspaceRailView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var documentStore: DocumentStore

    var body: some View {
        VStack(spacing: 10) {
            Color.clear
                .frame(height: 42)

            ForEach(workspaceStore.knownWorkspaces) { workspace in
                Button {
                    workspaceStore.activate(workspace)
                    documentStore.activate(workspace: workspace)
                } label: {
                    WorkspaceIconView(
                        title: initials(for: workspace),
                        color: color(for: workspace),
                        isSelected: workspaceStore.activeWorkspace?.id == workspace.id
                    )
                }
                .buttonStyle(.plain)
                .help(workspace.displayName)
            }

            Spacer()

            Button {
                workspaceStore.presentWorkspacePicker()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 32, height: 32)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .help("Open Workspace")
        }
        .padding(.vertical, 12)
        .frame(width: 54)
        .background(.bar)
    }

    private func initials(for workspace: Workspace) -> String {
        let parts = workspace.displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)

        if parts.isEmpty {
            return String(workspace.displayName.prefix(1)).uppercased()
        }

        return String(parts).uppercased()
    }

    private func color(for workspace: Workspace) -> Color {
        switch workspace.colorName {
        case .blue: .blue
        case .purple: .purple
        case .indigo: .indigo
        case .teal: .teal
        case .green: .green
        case .mint: .mint
        case .orange: .orange
        case .yellow: .yellow
        case .red: .red
        case .pink: .pink
        }
    }
}

private struct WorkspaceIconView: View {
    let title: String
    let color: Color
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 9)
                .fill(color.gradient)
                .frame(width: 32, height: 32)
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(isSelected ? Color.primary.opacity(0.40) : Color.white.opacity(0.18), lineWidth: isSelected ? 2 : 1)
                }

            if isSelected {
                Capsule()
                    .fill(Color.primary)
                    .frame(width: 3, height: 18)
                    .offset(x: -8)
            }

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
        }
        .frame(width: 40, height: 32)
    }
}
