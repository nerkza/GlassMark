import Foundation

/// Holds transient, app-wide UI command state that views and menus share:
/// Quick Open presentation, editor formatting commands, and outline navigation.
@MainActor
final class CommandStore: ObservableObject {
    @Published var isQuickOpenPresented = false
    @Published var isOutlineVisible = false
    @Published var pendingEditorCommand: EditorCommandRequest?
    @Published var outlineScrollRequest: OutlineScrollRequest?
    /// UTF-16 offset at the top of the editor viewport, used to highlight the
    /// current heading in the outline (scroll-spy).
    @Published var activeOutlineCharacterIndex: Int = 0

    func presentQuickOpen() {
        isQuickOpenPresented = true
    }

    func toggleOutline() {
        isOutlineVisible.toggle()
    }

    func run(_ command: EditorCommand) {
        pendingEditorCommand = EditorCommandRequest(command: command)
    }

    func scrollToOutlineItem(characterIndex: Int, headingOrdinal: Int) {
        outlineScrollRequest = OutlineScrollRequest(characterIndex: characterIndex, headingOrdinal: headingOrdinal)
    }
}
