import Foundation

@MainActor
final class DocumentStore: ObservableObject {
    @Published var document: EditorDocument?
    @Published private(set) var openDocuments: [EditorDocument] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var saveMessage: String?

    private let persistenceService = FilePersistenceService()
    private var openDocumentsByWorkspaceID: [Workspace.ID: [EditorDocument]] = [:]
    private var selectedDocumentIDByWorkspaceID: [Workspace.ID: EditorDocument.ID] = [:]

    var canSave: Bool {
        document?.isDirty == true
    }

    func open(_ file: WorkspaceFile, workspace: Workspace) {
        guard file.isEditable else { return }

        if let existingDocument = openDocumentsByWorkspaceID[workspace.id]?.first(where: { $0.file.id == file.id }) {
            selectDocument(id: existingDocument.id)
            return
        }

        do {
            let text = try URLSecurityScope.withAccess(to: workspace.rootURL) {
                try persistenceService.readText(from: file.url)
            }
            let openedDocument = EditorDocument(
                file: file,
                workspaceID: workspace.id,
                workspaceRootURL: workspace.rootURL,
                text: text,
                savedText: text,
                loadedAt: .now
            )
            var workspaceDocuments = openDocumentsByWorkspaceID[workspace.id] ?? []
            workspaceDocuments.append(openedDocument)
            openDocumentsByWorkspaceID[workspace.id] = workspaceDocuments
            selectedDocumentIDByWorkspaceID[workspace.id] = openedDocument.id
            openDocuments = workspaceDocuments
            document = openedDocument
            saveMessage = nil
        } catch {
            errorMessage = "Could not open \(file.name): \(error.localizedDescription)"
        }
    }

    func updateText(_ text: String) {
        guard var document else { return }

        document.text = text
        replace(document)
        saveMessage = nil
    }

    func save() {
        guard var document else { return }

        do {
            try URLSecurityScope.withAccess(to: document.workspaceRootURL) {
                try persistenceService.writeText(document.text, to: document.file.url)
            }
            document.savedText = document.text
            replace(document)
            saveMessage = "Saved \(document.file.name)"
        } catch {
            errorMessage = "Could not save \(document.file.name): \(error.localizedDescription)"
        }
    }

    func selectDocument(id: EditorDocument.ID) {
        guard let selectedDocument = openDocuments.first(where: { $0.id == id }) else { return }

        selectedDocumentIDByWorkspaceID[selectedDocument.workspaceID] = selectedDocument.id
        document = selectedDocument
        saveMessage = nil
    }

    func closeDocument(id: EditorDocument.ID) {
        guard let workspaceID = openDocuments.first(where: { $0.id == id })?.workspaceID else { return }
        var workspaceDocuments = openDocumentsByWorkspaceID[workspaceID] ?? []
        guard let closedIndex = workspaceDocuments.firstIndex(where: { $0.id == id }) else { return }

        let wasSelected = document?.id == id
        workspaceDocuments.remove(at: closedIndex)
        openDocumentsByWorkspaceID[workspaceID] = workspaceDocuments
        openDocuments = workspaceDocuments

        if wasSelected {
            let nextIndex = min(closedIndex, workspaceDocuments.count - 1)
            let nextDocument = nextIndex >= 0 ? workspaceDocuments[nextIndex] : nil
            document = nextDocument
            selectedDocumentIDByWorkspaceID[workspaceID] = nextDocument?.id
        }
    }

    func closeDocuments(for file: WorkspaceFile) {
        for document in openDocuments where document.file.url == file.url || document.file.url.path.hasPrefix(file.url.path + "/") {
            closeDocument(id: document.id)
        }
    }

    func moveOpenDocuments(from source: WorkspaceFile, to newURL: URL, rootURL: URL) {
        let affectedDocuments = openDocuments.filter {
            $0.file.url == source.url || $0.file.url.path.hasPrefix(source.url.path + "/")
        }

        for var document in affectedDocuments {
            let movedURL: URL
            if document.file.url == source.url {
                movedURL = newURL
            } else {
                let suffix = String(document.file.url.path.dropFirst(source.url.path.count + 1))
                movedURL = newURL.appendingPathComponent(suffix)
            }

            document.file = WorkspaceFile(
                url: movedURL,
                rootURL: rootURL,
                kind: document.file.kind,
                children: document.file.children
            )
            document.workspaceRootURL = rootURL
            replace(document)
        }
    }

    func activate(workspace: Workspace?) {
        guard let workspace else {
            openDocuments = []
            document = nil
            return
        }

        let workspaceDocuments = openDocumentsByWorkspaceID[workspace.id] ?? []
        openDocuments = workspaceDocuments

        if let selectedID = selectedDocumentIDByWorkspaceID[workspace.id],
           let selectedDocument = workspaceDocuments.first(where: { $0.id == selectedID }) {
            document = selectedDocument
        } else {
            document = workspaceDocuments.first
            selectedDocumentIDByWorkspaceID[workspace.id] = workspaceDocuments.first?.id
        }
        saveMessage = nil
    }

    func clearError() {
        errorMessage = nil
    }

    private func replace(_ updatedDocument: EditorDocument) {
        var workspaceDocuments = openDocumentsByWorkspaceID[updatedDocument.workspaceID] ?? []

        if let index = workspaceDocuments.firstIndex(where: { $0.id == updatedDocument.id }) {
            workspaceDocuments[index] = updatedDocument
        } else {
            workspaceDocuments.append(updatedDocument)
        }

        openDocumentsByWorkspaceID[updatedDocument.workspaceID] = workspaceDocuments
        selectedDocumentIDByWorkspaceID[updatedDocument.workspaceID] = updatedDocument.id
        openDocuments = workspaceDocuments
        document = updatedDocument
    }
}
