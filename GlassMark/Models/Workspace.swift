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

    private enum CodingKeys: String, CodingKey {
        case id, displayName, rootURL, bookmarkData, lastOpenedAt, isPinned, colorName
    }

    /// Tolerant decoding so workspaces saved by older builds (missing additive
    /// fields like `isPinned` or `colorName`) still restore instead of erroring.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        rootURL = try container.decode(URL.self, forKey: .rootURL)
        bookmarkData = try container.decode(Data.self, forKey: .bookmarkData)
        lastOpenedAt = (try? container.decode(Date.self, forKey: .lastOpenedAt)) ?? .now
        isPinned = (try? container.decode(Bool.self, forKey: .isPinned)) ?? false
        colorName = (try? container.decode(WorkspaceColorName.self, forKey: .colorName)) ?? .random()
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
