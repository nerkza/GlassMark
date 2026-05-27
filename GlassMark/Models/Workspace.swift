import Foundation

struct Workspace: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var displayName: String
    var rootURL: URL
    var bookmarkData: Data
    var lastOpenedAt: Date
    var isPinned: Bool
    var colorName: WorkspaceColorName

    init(
        id: UUID = UUID(),
        displayName: String,
        rootURL: URL,
        bookmarkData: Data,
        lastOpenedAt: Date = .now,
        isPinned: Bool = false,
        colorName: WorkspaceColorName = .random()
    ) {
        self.id = id
        self.displayName = displayName
        self.rootURL = rootURL
        self.bookmarkData = bookmarkData
        self.lastOpenedAt = lastOpenedAt
        self.isPinned = isPinned
        self.colorName = colorName
    }
}

enum WorkspaceColorName: String, CaseIterable, Codable, Hashable {
    case blue
    case purple
    case indigo
    case teal
    case green
    case mint
    case orange
    case yellow
    case red
    case pink

    static func random() -> WorkspaceColorName {
        allCases.randomElement() ?? .blue
    }
}
