import Foundation

/// A single heading entry for the outline panel.
struct MarkdownOutlineItem: Identifiable, Equatable {
    let level: Int
    let title: String
    let lineIndex: Int
    /// UTF-16 offset of the heading line, suitable for an `NSRange` location.
    let characterIndex: Int

    var id: Int { characterIndex }
}

/// Extracts an ATX-heading outline from Markdown text.
///
/// Headings inside fenced code blocks and leading YAML frontmatter are ignored so
/// the outline matches what a reader sees in the preview.
enum MarkdownOutline {
    static func items(from text: String) -> [MarkdownOutlineItem] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        var items: [MarkdownOutlineItem] = []
        var characterIndex = 0
        var insideFence = false
        var openFenceCharacter: Character = "`"
        var skippingFrontmatter = lines.first == "---"
        var consumedFrontmatterStart = false

        for (lineIndex, line) in lines.enumerated() {
            defer { characterIndex += (line as NSString).length + 1 }

            if skippingFrontmatter {
                if !consumedFrontmatterStart {
                    consumedFrontmatterStart = true
                    continue
                }
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed == "---" || trimmed == "..." {
                    skippingFrontmatter = false
                }
                continue
            }

            if let fence = fenceCharacter(of: line) {
                if insideFence {
                    if fence == openFenceCharacter { insideFence = false }
                } else {
                    insideFence = true
                    openFenceCharacter = fence
                }
                continue
            }

            guard !insideFence else { continue }

            if let heading = heading(in: line) {
                items.append(
                    MarkdownOutlineItem(
                        level: heading.level,
                        title: heading.title,
                        lineIndex: lineIndex,
                        characterIndex: characterIndex
                    )
                )
            }
        }

        return items
    }

    private static func fenceCharacter(of line: String) -> Character? {
        let trimmed = line.drop(while: { $0 == " " })
        guard let first = trimmed.first, first == "`" || first == "~" else { return nil }
        let count = trimmed.prefix(while: { $0 == first }).count
        return count >= 3 ? first : nil
    }

    private static func heading(in line: String) -> (level: Int, title: String)? {
        let indent = line.prefix(while: { $0 == " " }).count
        guard indent <= 3 else { return nil }
        let chars = Array(line.dropFirst(indent))
        var level = 0
        while level < chars.count, chars[level] == "#" { level += 1 }
        guard level >= 1, level <= 6, level < chars.count, chars[level] == " " else { return nil }

        var title = String(chars[(level + 1)...]).trimmingCharacters(in: .whitespaces)
        while title.hasSuffix("#") { title.removeLast() }
        title = MarkdownHTMLRenderer().renderPlainText(title.trimmingCharacters(in: .whitespaces))
        guard !title.isEmpty else { return nil }
        return (level, title)
    }
}
