import Foundation

struct EditorDocument: Identifiable, Equatable {
    var file: WorkspaceFile
    var workspaceID: Workspace.ID
    var workspaceRootURL: URL
    var text: String
    var savedText: String
    var loadedAt: Date

    var id: WorkspaceFile.ID {
        file.id
    }

    var isDirty: Bool {
        text != savedText
    }
}
