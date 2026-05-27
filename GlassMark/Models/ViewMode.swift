import Foundation

enum ViewMode: String, CaseIterable, Codable, Identifiable {
    case editorOnly
    case split
    case previewOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .editorOnly: "Editor"
        case .split: "Split"
        case .previewOnly: "Preview"
        }
    }
}
