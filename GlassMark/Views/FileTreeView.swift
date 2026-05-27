import SwiftUI
import UniformTypeIdentifiers

struct FileTreeView: View {
    let files: [WorkspaceFile]
    let selectedFileID: WorkspaceFile.ID?
    @Binding var expandedFileIDs: Set<WorkspaceFile.ID>
    let onSelect: (WorkspaceFile) -> Void
    let onNewMarkdownFile: (WorkspaceFile) -> Void
    let onNewFolder: (WorkspaceFile) -> Void
    let onRename: (WorkspaceFile) -> Void
    let onCut: (WorkspaceFile) -> Void
    let onCopy: (WorkspaceFile) -> Void
    let onPaste: (WorkspaceFile) -> Void
    let canPaste: Bool
    let onDuplicate: (WorkspaceFile) -> Void
    let onRevealInFinder: (WorkspaceFile) -> Void
    let onMoveToTrash: (WorkspaceFile) -> Void
    let onMove: (WorkspaceFile, WorkspaceFile) -> Void

    var body: some View {
        List {
            ForEach(files) { file in
                FileTreeNodeView(
                    file: file,
                    allFiles: files,
                    selectedFileID: selectedFileID,
                    expandedFileIDs: $expandedFileIDs,
                    onSelect: onSelect,
                    onNewMarkdownFile: onNewMarkdownFile,
                    onNewFolder: onNewFolder,
                    onRename: onRename,
                    onCut: onCut,
                    onCopy: onCopy,
                    onPaste: onPaste,
                    canPaste: canPaste,
                    onDuplicate: onDuplicate,
                    onRevealInFinder: onRevealInFinder,
                    onMoveToTrash: onMoveToTrash,
                    onMove: onMove
                )
            }
        }
        .listStyle(.sidebar)
    }
}

private struct FileTreeNodeView: View {
    let file: WorkspaceFile
    let allFiles: [WorkspaceFile]
    let selectedFileID: WorkspaceFile.ID?
    @Binding var expandedFileIDs: Set<WorkspaceFile.ID>
    let onSelect: (WorkspaceFile) -> Void
    let onNewMarkdownFile: (WorkspaceFile) -> Void
    let onNewFolder: (WorkspaceFile) -> Void
    let onRename: (WorkspaceFile) -> Void
    let onCut: (WorkspaceFile) -> Void
    let onCopy: (WorkspaceFile) -> Void
    let onPaste: (WorkspaceFile) -> Void
    let canPaste: Bool
    let onDuplicate: (WorkspaceFile) -> Void
    let onRevealInFinder: (WorkspaceFile) -> Void
    let onMoveToTrash: (WorkspaceFile) -> Void
    let onMove: (WorkspaceFile, WorkspaceFile) -> Void

    var body: some View {
        if file.isDirectory {
            DisclosureGroup(isExpanded: expandedBinding) {
                ForEach(file.children ?? []) { child in
                    FileTreeNodeView(
                        file: child,
                        allFiles: allFiles,
                        selectedFileID: selectedFileID,
                        expandedFileIDs: $expandedFileIDs,
                        onSelect: onSelect,
                        onNewMarkdownFile: onNewMarkdownFile,
                        onNewFolder: onNewFolder,
                        onRename: onRename,
                        onCut: onCut,
                        onCopy: onCopy,
                        onPaste: onPaste,
                        canPaste: canPaste,
                        onDuplicate: onDuplicate,
                        onRevealInFinder: onRevealInFinder,
                        onMoveToTrash: onMoveToTrash,
                        onMove: onMove
                    )
                }
            } label: {
                rowLabel
            }
            .fileTreeActions(
                file: file,
                allFiles: allFiles,
                selectedFileID: selectedFileID,
                handleDrop: handleDrop,
                onSelect: onSelect,
                onNewMarkdownFile: onNewMarkdownFile,
                onNewFolder: onNewFolder,
                onRename: onRename,
                onCut: onCut,
                onCopy: onCopy,
                onPaste: onPaste,
                canPaste: canPaste,
                onDuplicate: onDuplicate,
                onRevealInFinder: onRevealInFinder,
                onMoveToTrash: onMoveToTrash
            )
        } else {
            rowLabel
                .fileTreeActions(
                    file: file,
                    allFiles: allFiles,
                    selectedFileID: selectedFileID,
                    handleDrop: handleDrop,
                    onSelect: onSelect,
                    onNewMarkdownFile: onNewMarkdownFile,
                    onNewFolder: onNewFolder,
                    onRename: onRename,
                    onCut: onCut,
                    onCopy: onCopy,
                    onPaste: onPaste,
                    canPaste: canPaste,
                    onDuplicate: onDuplicate,
                    onRevealInFinder: onRevealInFinder,
                    onMoveToTrash: onMoveToTrash
                )
        }
    }

    private var rowLabel: some View {
        FileRow(file: file, isSelected: file.id == selectedFileID)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if file.isDirectory {
                    toggleExpanded()
                } else if file.isEditable {
                    onSelect(file)
                }
            }
            .onTapGesture {
                if file.isEditable {
                    onSelect(file)
                }
            }
            .listRowBackground(file.id == selectedFileID ? Color.accentColor.opacity(0.18) : Color.clear)
    }

    private var expandedBinding: Binding<Bool> {
        Binding(
            get: { expandedFileIDs.contains(file.id) },
            set: { isExpanded in
                if isExpanded {
                    expandedFileIDs.insert(file.id)
                } else {
                    expandedFileIDs.remove(file.id)
                }
            }
        )
    }

    private func toggleExpanded() {
        if expandedFileIDs.contains(file.id) {
            expandedFileIDs.remove(file.id)
        } else {
            expandedFileIDs.insert(file.id)
        }
    }

    private func handleDrop(providers: [NSItemProvider], target: WorkspaceFile) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let string = object as? String,
                  let sourceURL = URL(string: string) else { return }

            DispatchQueue.main.async {
                guard let sourceFile = findFile(with: sourceURL, in: allFiles),
                      sourceFile.url != target.url else { return }

                onMove(sourceFile, target)
            }
        }

        return true
    }

    private func findFile(with url: URL, in files: [WorkspaceFile]) -> WorkspaceFile? {
        for file in files {
            if file.url == url {
                return file
            }

            if let children = file.children,
               let match = findFile(with: url, in: children) {
                return match
            }
        }

        return nil
    }
}

private extension View {
    func fileTreeActions(
        file: WorkspaceFile,
        allFiles: [WorkspaceFile],
        selectedFileID: WorkspaceFile.ID?,
        handleDrop: @escaping ([NSItemProvider], WorkspaceFile) -> Bool,
        onSelect: @escaping (WorkspaceFile) -> Void,
        onNewMarkdownFile: @escaping (WorkspaceFile) -> Void,
        onNewFolder: @escaping (WorkspaceFile) -> Void,
        onRename: @escaping (WorkspaceFile) -> Void,
        onCut: @escaping (WorkspaceFile) -> Void,
        onCopy: @escaping (WorkspaceFile) -> Void,
        onPaste: @escaping (WorkspaceFile) -> Void,
        canPaste: Bool,
        onDuplicate: @escaping (WorkspaceFile) -> Void,
        onRevealInFinder: @escaping (WorkspaceFile) -> Void,
        onMoveToTrash: @escaping (WorkspaceFile) -> Void
    ) -> some View {
        self
            .onDrag {
                NSItemProvider(object: file.url.absoluteString as NSString)
            }
            .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                handleDrop(providers, file)
            }
            .contextMenu {
                if file.isEditable {
                    Button("Open") {
                        onSelect(file)
                    }

                    Divider()
                }

                Button("New Markdown File") {
                    onNewMarkdownFile(file)
                }

                Button("New Folder") {
                    onNewFolder(file)
                }

                Button("Rename…") {
                    onRename(file)
                }

                Divider()

                Button("Cut") {
                    onCut(file)
                }

                Button("Copy") {
                    onCopy(file)
                }

                Button("Paste") {
                    onPaste(file)
                }
                .disabled(!canPaste)

                Button("Duplicate") {
                    onDuplicate(file)
                }

                Divider()

                Button("Reveal in Finder") {
                    onRevealInFinder(file)
                }

                Divider()

                Button("Move to Trash", role: .destructive) {
                    onMoveToTrash(file)
                }
            }
    }
}

private struct FileRow: View {
    let file: WorkspaceFile
    let isSelected: Bool

    var body: some View {
        Label {
            Text(file.name)
                .lineLimit(1)
                .fontWeight(isSelected ? .semibold : .regular)
        } icon: {
            Image(systemName: iconName)
                .foregroundStyle(isSelected ? Color.accentColor : file.isDirectory ? Color.secondary : Color.primary)
        }
    }

    private var iconName: String {
        switch file.kind {
        case .folder: "folder"
        case .markdown: "doc.richtext"
        case .text: "doc.text"
        case .other: "doc"
        }
    }
}
