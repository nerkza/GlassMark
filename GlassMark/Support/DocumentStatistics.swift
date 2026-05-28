import Foundation

/// Lightweight reading statistics shown in the editor status bar.
struct DocumentStatistics: Equatable {
    let words: Int
    let characters: Int
    let lines: Int
    /// Estimated reading time in whole minutes (200 words per minute, minimum 1).
    let readingMinutes: Int

    static let wordsPerMinute = 200

    init(text: String) {
        let words = text.split { $0 == " " || $0 == "\n" || $0 == "\t" || $0 == "\r" }
        self.words = words.count
        self.characters = text.count
        self.lines = text.isEmpty ? 0 : text.components(separatedBy: "\n").count
        self.readingMinutes = words.isEmpty ? 0 : max(1, Int((Double(words.count) / Double(Self.wordsPerMinute)).rounded(.up)))
    }
}
