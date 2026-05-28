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

/// Request to scroll the editor to a heading selected in the outline.
struct OutlineScrollRequest: Identifiable, Equatable {
    let id = UUID()
    let characterIndex: Int
}
