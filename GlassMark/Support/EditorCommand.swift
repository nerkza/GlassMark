import Foundation

/// Editing actions routed from the toolbar, menus, and keyboard shortcuts into
/// the focused editor text view.
enum EditorCommand: Equatable {
    case undo
    case redo
    case copy
    case paste
    case bold
    case italic
    case inlineCode
    case strikethrough
    case link
    case heading(level: Int)
    case bulletList
    case numberList
}

/// Identified wrapper so SwiftUI can observe repeated commands of the same kind.
struct EditorCommandRequest: Identifiable, Equatable {
    let id = UUID()
    let command: EditorCommand
}

/// Request to scroll the editor and preview to a heading selected in the outline.
struct OutlineScrollRequest: Identifiable, Equatable {
    let id = UUID()
    /// UTF-16 offset of the heading in the source text (used by the editor).
    let characterIndex: Int
    /// Position of the heading among all document headings (used by the preview).
    let headingOrdinal: Int
}

/// Which split pane originated a scroll, so the other pane can follow without
/// echoing back.
enum ScrollSource: Equatable {
    case editor
    case preview
}

/// A source-line scroll position shared between the editor and preview panes for
/// line-mapped sync.
struct ScrollSync: Equatable {
    let token: Int
    let line: Int
    let source: ScrollSource
}
