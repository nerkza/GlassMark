import Foundation

enum FileType {
    case markdown
    case text
    case other

    init?(url: URL) {
        switch url.pathExtension.lowercased() {
        case "md", "markdown", "mdown":
            self = .markdown
        case "txt":
            self = .text
        default:
            self = .other
        }
    }

    var shouldShowInSidebar: Bool {
        switch self {
        case .markdown, .text: true
        case .other: false
        }
    }

    var workspaceKind: WorkspaceFile.Kind {
        switch self {
        case .markdown: .markdown
        case .text: .text
        case .other: .other
        }
    }
}
