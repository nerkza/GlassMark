import Foundation

struct WorkspaceFile: Identifiable, Equatable, Hashable {
    let id: URL
    let url: URL
    let name: String
    let relativePath: String
    let kind: Kind
    var children: [WorkspaceFile]?

    enum Kind: String, Equatable, Hashable {
        case folder
        case markdown
        case text
        case other
    }

    var isDirectory: Bool {
        kind == .folder
    }

    var isEditable: Bool {
        kind == .markdown || kind == .text
    }

    init(url: URL, rootURL: URL, kind: Kind, children: [WorkspaceFile]? = nil) {
        self.id = url
        self.url = url
        self.name = url.lastPathComponent.isEmpty ? rootURL.lastPathComponent : url.lastPathComponent
        self.relativePath = url.path.replacingOccurrences(of: rootURL.path + "/", with: "")
        self.kind = kind
        self.children = children
    }
}
