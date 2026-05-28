import AppKit
import Foundation

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published private(set) var knownWorkspaces: [Workspace] = []
    @Published var activeWorkspace: Workspace?
    @Published private(set) var fileTree: [WorkspaceFile] = []
    @Published private(set) var errorMessage: String?

    private let fileTreeService = FileTreeService()
    private let filePersistenceService = FilePersistenceService()
    private let defaultsKey = "knownWorkspaces"
    private var fileTreesByWorkspaceID: [Workspace.ID: [WorkspaceFile]] = [:]
    private var fileTreeLoadToken = 0

    func restoreKnownWorkspaces() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }

        do {
            knownWorkspaces = try JSONDecoder().decode([Workspace].self, from: data)
            if let mostRecent = knownWorkspaces.sorted(by: { $0.lastOpenedAt > $1.lastOpenedAt }).first {
                activate(mostRecent)
            }
        } catch {
            errorMessage = "Could not restore workspaces: \(error.localizedDescription)"
        }
    }

    func presentWorkspacePicker() {
        let panel = NSOpenPanel()
        panel.title = "Open Workspace"
        panel.prompt = "Open"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let workspace = Workspace(
                displayName: url.lastPathComponent,
                rootURL: url,
                bookmarkData: bookmarkData,
                lastOpenedAt: .now,
                colorName: unusedRandomColor()
            )
            rememberAndOpen(workspace)
        } catch {
            errorMessage = "Could not save workspace access: \(error.localizedDescription)"
        }
    }

    func open(_ workspace: Workspace) {
        do {
            var stale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: workspace.bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )

            let resolvedWorkspace = Workspace(
                id: workspace.id,
                displayName: workspace.displayName,
                rootURL: resolvedURL,
                bookmarkData: workspace.bookmarkData,
                lastOpenedAt: .now,
                isPinned: workspace.isPinned,
                colorName: workspace.colorName
            )

            remember(resolvedWorkspace)
            activeWorkspace = resolvedWorkspace
            refreshFileTree()
        } catch {
            errorMessage = "Could not open workspace: \(error.localizedDescription)"
        }
    }

    func activate(_ workspace: Workspace) {
        open(workspace)
    }

    func refreshFileTree() {
        guard let activeWorkspace else {
            fileTree = []
            return
        }

        let workspaceID = activeWorkspace.id
        let rootURL = activeWorkspace.rootURL
        let service = fileTreeService
        fileTreeLoadToken += 1
        let token = fileTreeLoadToken

        // Load off the main thread so large workspaces don't block the UI.
        Task.detached(priority: .userInitiated) {
            var tree: [WorkspaceFile] = []
            var failure: String?
            do {
                tree = try URLSecurityScope.withAccess(to: rootURL) {
                    try service.loadTree(rootURL: rootURL)
                }
            } catch {
                failure = error.localizedDescription
            }
            let loaded = tree
            await MainActor.run {
                self.applyFileTree(loaded, failure: failure, workspaceID: workspaceID, token: token)
            }
        }
    }

    private func applyFileTree(_ tree: [WorkspaceFile], failure: String?, workspaceID: Workspace.ID, token: Int) {
        guard token == fileTreeLoadToken else { return }

        if let failure {
            fileTree = fileTreesByWorkspaceID[workspaceID] ?? []
            errorMessage = "Could not load workspace files: \(failure)"
            return
        }

        fileTreesByWorkspaceID[workspaceID] = tree
        if activeWorkspace?.id == workspaceID {
            fileTree = tree
        }
    }

    func createMarkdownFile() -> WorkspaceFile? {
        guard let activeWorkspace else { return nil }

        do {
            let fileURL = try URLSecurityScope.withAccess(to: activeWorkspace.rootURL) {
                try filePersistenceService.createMarkdownFile(in: activeWorkspace.rootURL)
            }
            refreshFileTree()
            return WorkspaceFile(url: fileURL, rootURL: activeWorkspace.rootURL, kind: .markdown)
        } catch {
            errorMessage = "Could not create Markdown file: \(error.localizedDescription)"
            return nil
        }
    }

    func createMarkdownFile(nextTo file: WorkspaceFile) -> WorkspaceFile? {
        guard let activeWorkspace else { return nil }

        do {
            let fileURL = try URLSecurityScope.withAccess(to: activeWorkspace.rootURL) {
                try filePersistenceService.createMarkdownFile(nextTo: file)
            }
            refreshFileTree()
            return WorkspaceFile(url: fileURL, rootURL: activeWorkspace.rootURL, kind: .markdown)
        } catch {
            errorMessage = "Could not create Markdown file: \(error.localizedDescription)"
            return nil
        }
    }

    func createFolder(nextTo file: WorkspaceFile) {
        guard let activeWorkspace else { return }

        do {
            try URLSecurityScope.withAccess(to: activeWorkspace.rootURL) {
                _ = try filePersistenceService.createFolder(nextTo: file)
            }
            refreshFileTree()
        } catch {
            errorMessage = "Could not create folder: \(error.localizedDescription)"
        }
    }

    func rename(_ file: WorkspaceFile, to proposedName: String) {
        guard let activeWorkspace else { return }

        do {
            try URLSecurityScope.withAccess(to: activeWorkspace.rootURL) {
                _ = try filePersistenceService.rename(file, to: proposedName)
            }
            refreshFileTree()
        } catch {
            errorMessage = "Could not rename \(file.name): \(error.localizedDescription)"
        }
    }

    func move(_ file: WorkspaceFile, to target: WorkspaceFile) -> URL? {
        guard let activeWorkspace else { return nil }

        do {
            let newURL = try URLSecurityScope.withAccess(to: activeWorkspace.rootURL) {
                try filePersistenceService.move(file, to: target)
            }
            refreshFileTree()
            return newURL
        } catch {
            errorMessage = "Could not move \(file.name): \(error.localizedDescription)"
            return nil
        }
    }

    func duplicate(_ file: WorkspaceFile) {
        guard let activeWorkspace else { return }

        do {
            try URLSecurityScope.withAccess(to: activeWorkspace.rootURL) {
                _ = try filePersistenceService.duplicate(file)
            }
            refreshFileTree()
        } catch {
            errorMessage = "Could not duplicate \(file.name): \(error.localizedDescription)"
        }
    }

    func copy(_ file: WorkspaceFile, to target: WorkspaceFile) {
        guard let activeWorkspace else { return }

        do {
            try URLSecurityScope.withAccess(to: activeWorkspace.rootURL) {
                _ = try filePersistenceService.copy(file, to: target)
            }
            refreshFileTree()
        } catch {
            errorMessage = "Could not copy \(file.name): \(error.localizedDescription)"
        }
    }

    func revealInFinder(_ file: WorkspaceFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    func moveToTrash(_ file: WorkspaceFile) {
        guard let activeWorkspace else { return }

        do {
            try URLSecurityScope.withAccess(to: activeWorkspace.rootURL) {
                try filePersistenceService.moveToTrash(file)
            }
            refreshFileTree()
        } catch {
            errorMessage = "Could not move \(file.name) to Trash: \(error.localizedDescription)"
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func rememberAndOpen(_ workspace: Workspace) {
        remember(workspace)
        open(workspace)
    }

    private func remember(_ workspace: Workspace) {
        if let index = knownWorkspaces.firstIndex(where: { $0.id == workspace.id || $0.rootURL == workspace.rootURL }) {
            var updatedWorkspace = workspace
            if updatedWorkspace.colorName == knownWorkspaces[index].colorName {
                knownWorkspaces[index] = updatedWorkspace
            } else {
                updatedWorkspace.colorName = knownWorkspaces[index].colorName
                knownWorkspaces[index] = updatedWorkspace
            }
        } else {
            knownWorkspaces.append(workspace)
        }
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(knownWorkspaces)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            errorMessage = "Could not persist workspaces: \(error.localizedDescription)"
        }
    }

    private func unusedRandomColor() -> WorkspaceColorName {
        let usedColors = Set(knownWorkspaces.map(\.colorName))
        let unusedColors = WorkspaceColorName.allCases.filter { !usedColors.contains($0) }
        return unusedColors.randomElement() ?? .random()
    }
}
