import Foundation

/// Converts Markdown (GitHub-flavored subset) into safe HTML.
///
/// The renderer escapes all text and never passes raw HTML through, so a local
/// document can be previewed without loading remote scripts or markup. It is a
/// pure value type with no I/O, which keeps it fast and unit-testable.
struct MarkdownHTMLRenderer {
    func renderBody(_ markdown: String) -> String {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        return renderBlocks(lines)
    }

    // MARK: - Block parsing

    private func renderBlocks(_ lines: [String]) -> String {
        var html: [String] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]

            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                continue
            }

            if let fence = fenceMarker(line) {
                let (block, next) = consumeFencedCode(lines, start: index, fence: fence)
                html.append(block)
                index = next
                continue
            }

            if isHorizontalRule(line) {
                html.append("<hr>")
                index += 1
                continue
            }

            if let heading = atxHeading(line) {
                html.append(heading)
                index += 1
                continue
            }

            if line.drop(while: { $0 == " " }).first == ">" {
                let (block, next) = consumeBlockquote(lines, start: index)
                html.append(block)
                index = next
                continue
            }

            if index + 1 < lines.count,
               line.contains("|"),
               isTableDelimiterRow(lines[index + 1]) {
                let (block, next) = consumeTable(lines, start: index)
                html.append(block)
                index = next
                continue
            }

            if listItem(line) != nil {
                let end = listBlockEnd(lines, start: index)
                html.append(renderList(Array(lines[index..<end])))
                index = end
                continue
            }

            let (block, next) = consumeParagraph(lines, start: index)
            html.append(block)
            index = next
        }

        return html.joined(separator: "\n")
    }

    // MARK: - Fenced code

    private struct Fence {
        let character: Character
        let count: Int
        let indent: Int
        let language: String
    }

    private func fenceMarker(_ line: String) -> Fence? {
        let indent = leadingSpaces(line)
        let trimmed = Array(line.dropFirst(indent))
        guard let first = trimmed.first, first == "`" || first == "~" else { return nil }

        var count = 0
        while count < trimmed.count, trimmed[count] == first { count += 1 }
        guard count >= 3 else { return nil }

        let info = String(trimmed[count...]).trimmingCharacters(in: .whitespaces)
        let language = info.split(separator: " ").first.map(String.init) ?? ""
        return Fence(character: first, count: count, indent: indent, language: language)
    }

    private func consumeFencedCode(_ lines: [String], start: Int, fence: Fence) -> (String, Int) {
        var body: [String] = []
        var index = start + 1

        while index < lines.count {
            let line = lines[index]
            if let closing = fenceMarker(line),
               closing.character == fence.character,
               closing.count >= fence.count,
               closing.language.isEmpty {
                index += 1
                break
            }
            let stripped = String(line.dropFirst(min(fence.indent, leadingSpaces(line))))
            body.append(stripped)
            index += 1
        }

        let escaped = body.map(escapeHTML).joined(separator: "\n")
        let languageClass = fence.language.isEmpty
            ? ""
            : " class=\"language-\(escapeAttribute(fence.language.lowercased()))\""
        return ("<pre><code\(languageClass)>\(escaped)</code></pre>", index)
    }

    // MARK: - Headings

    private func atxHeading(_ line: String) -> String? {
        let indent = leadingSpaces(line)
        guard indent <= 3 else { return nil }
        let trimmed = Array(line.dropFirst(indent))
        var level = 0
        while level < trimmed.count, trimmed[level] == "#" { level += 1 }
        guard level >= 1, level <= 6 else { return nil }
        guard level < trimmed.count, trimmed[level] == " " else {
            return level == trimmed.count ? "<h\(level) id=\"\(slug(""))\"></h\(level)>" : nil
        }

        var content = String(trimmed[(level + 1)...]).trimmingCharacters(in: .whitespaces)
        while content.hasSuffix("#") { content.removeLast() }
        content = content.trimmingCharacters(in: .whitespaces)

        let id = slug(content)
        return "<h\(level) id=\"\(id)\">\(renderInline(content))</h\(level)>"
    }

    /// Slug used both for in-page anchors and for the outline panel to jump to.
    static func slug(for heading: String) -> String {
        MarkdownHTMLRenderer().slug(heading)
    }

    private func slug(_ text: String) -> String {
        let lowered = renderPlainText(text).lowercased()
        var result = ""
        var lastWasHyphen = false
        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
                lastWasHyphen = false
            } else if scalar == " " || scalar == "-" || scalar == "_" {
                if !lastWasHyphen && !result.isEmpty {
                    result.append("-")
                    lastWasHyphen = true
                }
            }
        }
        while result.hasSuffix("-") { result.removeLast() }
        return result
    }

    // MARK: - Horizontal rule

    private func isHorizontalRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return false }
        for marker in ["-", "*", "_"] {
            let stripped = trimmed.replacingOccurrences(of: " ", with: "")
            if !stripped.isEmpty, stripped.allSatisfy({ String($0) == marker }) {
                return true
            }
        }
        return false
    }

    // MARK: - Blockquote

    private func consumeBlockquote(_ lines: [String], start: Int) -> (String, Int) {
        var inner: [String] = []
        var index = start

        while index < lines.count {
            let line = lines[index]
            let trimmedLeading = line.drop(while: { $0 == " " })
            if trimmedLeading.first == ">" {
                var content = String(trimmedLeading.dropFirst())
                if content.hasPrefix(" ") { content.removeFirst() }
                inner.append(content)
                index += 1
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                break
            } else {
                // Lazy continuation line.
                inner.append(line)
                index += 1
            }
        }

        return ("<blockquote>\n\(renderBlocks(inner))\n</blockquote>", index)
    }

    // MARK: - Tables

    private func isTableDelimiterRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("-") else { return false }
        let cells = splitTableRow(trimmed)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let value = cell.trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { return false }
            let body = value.replacingOccurrences(of: ":", with: "")
            return !body.isEmpty && body.allSatisfy { $0 == "-" }
        }
    }

    private enum ColumnAlignment {
        case none, left, center, right

        var style: String {
            switch self {
            case .none: ""
            case .left: " style=\"text-align:left\""
            case .center: " style=\"text-align:center\""
            case .right: " style=\"text-align:right\""
            }
        }
    }

    private func consumeTable(_ lines: [String], start: Int) -> (String, Int) {
        let headerCells = splitTableRow(lines[start])
        let alignments = splitTableRow(lines[start + 1]).map(columnAlignment)

        var rows: [[String]] = []
        var index = start + 2
        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty || !line.contains("|") {
                break
            }
            rows.append(splitTableRow(line))
            index += 1
        }

        func alignment(_ column: Int) -> ColumnAlignment {
            column < alignments.count ? alignments[column] : .none
        }

        var html = "<table>\n<thead>\n<tr>"
        for (column, cell) in headerCells.enumerated() {
            html += "<th\(alignment(column).style)>\(renderInline(cell.trimmingCharacters(in: .whitespaces)))</th>"
        }
        html += "</tr>\n</thead>\n<tbody>\n"

        for row in rows {
            html += "<tr>"
            for column in 0..<headerCells.count {
                let cell = column < row.count ? row[column].trimmingCharacters(in: .whitespaces) : ""
                html += "<td\(alignment(column).style)>\(renderInline(cell))</td>"
            }
            html += "</tr>\n"
        }

        html += "</tbody>\n</table>"
        return (html, index)
    }

    private func columnAlignment(_ cell: String) -> ColumnAlignment {
        let value = cell.trimmingCharacters(in: .whitespaces)
        let left = value.hasPrefix(":")
        let right = value.hasSuffix(":")
        switch (left, right) {
        case (true, true): return .center
        case (true, false): return .left
        case (false, true): return .right
        case (false, false): return .none
        }
    }

    private func splitTableRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }

        var cells: [String] = []
        var current = ""
        var escaped = false
        for character in trimmed {
            if escaped {
                current.append(character)
                escaped = false
            } else if character == "\\" {
                current.append(character)
                escaped = true
            } else if character == "|" {
                cells.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        cells.append(current)
        return cells
    }

    // MARK: - Lists

    private struct ListItemMatch {
        let ordered: Bool
        let indent: Int
        let contentIndent: Int
        let content: String
        let startNumber: Int
    }

    private func listItem(_ line: String) -> ListItemMatch? {
        let indent = leadingSpaces(line)
        guard indent <= 6 else { return nil }
        let chars = Array(line.dropFirst(indent))
        guard let first = chars.first else { return nil }

        if first == "-" || first == "*" || first == "+" {
            guard chars.count >= 2, chars[1] == " " else { return nil }
            let afterMarker = sliceAfterSpaces(chars, from: 2)
            return ListItemMatch(
                ordered: false,
                indent: indent,
                contentIndent: indent + afterMarker.offset,
                content: afterMarker.text,
                startNumber: 1
            )
        }

        if first.isNumber {
            var cursor = 0
            while cursor < chars.count, chars[cursor].isNumber { cursor += 1 }
            guard cursor < chars.count, chars[cursor] == "." || chars[cursor] == ")" else { return nil }
            guard cursor + 1 < chars.count, chars[cursor + 1] == " " else { return nil }
            let number = Int(String(chars[0..<cursor])) ?? 1
            let afterMarker = sliceAfterSpaces(chars, from: cursor + 2)
            return ListItemMatch(
                ordered: true,
                indent: indent,
                contentIndent: indent + afterMarker.offset,
                content: afterMarker.text,
                startNumber: number
            )
        }

        return nil
    }

    private func sliceAfterSpaces(_ chars: [Character], from start: Int) -> (text: String, offset: Int) {
        var cursor = start
        while cursor < chars.count, chars[cursor] == " " { cursor += 1 }
        return (String(chars[min(cursor, chars.count)...]), cursor)
    }

    private func listBlockEnd(_ lines: [String], start: Int) -> Int {
        guard let base = listItem(lines[start])?.indent else { return start + 1 }
        var index = start + 1
        var lastNonBlank = start

        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                continue
            }
            let indent = leadingSpaces(line)
            if listItem(line) != nil && indent >= base {
                lastNonBlank = index
                index += 1
            } else if indent > base {
                lastNonBlank = index
                index += 1
            } else {
                break
            }
        }

        return lastNonBlank + 1
    }

    private func renderList(_ lines: [String]) -> String {
        guard let firstItem = lines.compactMap(listItem).first else { return "" }
        let base = firstItem.indent

        // Group lines into items at the base indent.
        var items: [[String]] = []
        var current: [String] = []
        for line in lines {
            if let match = listItem(line), match.indent == base {
                if !current.isEmpty { items.append(current) }
                current = [line]
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { items.append(current) }

        let isTask = items.allSatisfy { taskMarker($0.first ?? "") != nil }
        var renderedItems: [String] = []

        for itemLines in items {
            guard let match = listItem(itemLines[0]) else { continue }
            var bodyLines = [match.content]
            for line in itemLines.dropFirst() {
                let dedent = min(match.contentIndent, leadingSpaces(line))
                bodyLines.append(String(line.dropFirst(dedent)))
            }

            if let task = taskMarker(itemLines[0]) {
                let checkbox = "<input type=\"checkbox\" disabled\(task.checked ? " checked" : "")> "
                bodyLines[0] = task.rest
                let inner = stripLoneParagraph(renderBlocks(bodyLines))
                renderedItems.append("<li class=\"task-list-item\">\(checkbox)\(inner)</li>")
            } else {
                let inner = stripLoneParagraph(renderBlocks(bodyLines))
                renderedItems.append("<li>\(inner)</li>")
            }
        }

        let body = renderedItems.joined(separator: "\n")
        if firstItem.ordered {
            let startAttribute = firstItem.startNumber != 1 ? " start=\"\(firstItem.startNumber)\"" : ""
            return "<ol\(startAttribute)>\n\(body)\n</ol>"
        }
        let classAttribute = isTask ? " class=\"contains-task-list\"" : ""
        return "<ul\(classAttribute)>\n\(body)\n</ul>"
    }

    private func taskMarker(_ line: String) -> (checked: Bool, rest: String)? {
        guard let match = listItem(line), !match.ordered else { return nil }
        let content = match.content
        if content.hasPrefix("[ ] ") || content == "[ ]" {
            return (false, String(content.dropFirst(min(4, content.count))))
        }
        if content.hasPrefix("[x] ") || content.hasPrefix("[X] ") || content == "[x]" || content == "[X]" {
            return (true, String(content.dropFirst(min(4, content.count))))
        }
        return nil
    }

    private func stripLoneParagraph(_ html: String) -> String {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("<p>"), trimmed.hasSuffix("</p>") else { return html }
        let inner = String(trimmed.dropFirst(3).dropLast(4))
        // Only unwrap when there is a single paragraph and no nested block elements.
        if inner.contains("<p>") || inner.contains("<ul") || inner.contains("<ol") || inner.contains("<pre") {
            return html
        }
        return inner
    }

    // MARK: - Paragraph

    private func consumeParagraph(_ lines: [String], start: Int) -> (String, Int) {
        var paragraph: [String] = []
        var index = start

        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty { break }
            if fenceMarker(line) != nil || atxHeading(line) != nil || isHorizontalRule(line) { break }
            if line.drop(while: { $0 == " " }).first == ">" { break }
            if listItem(line) != nil { break }
            paragraph.append(line.trimmingCharacters(in: .whitespaces))
            index += 1
        }

        let joined = paragraph.joined(separator: "\n")
        let withBreaks = applyHardLineBreaks(joined)
        return ("<p>\(withBreaks)</p>", index)
    }

    private func applyHardLineBreaks(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let rendered = lines.map { renderInline($0.trimmingCharacters(in: .whitespaces)) }
        return rendered.joined(separator: "<br>\n")
    }

    // MARK: - Inline rendering

    /// Renders inline Markdown (emphasis, code, links, images) to HTML.
    func renderInline(_ text: String) -> String {
        renderInline(Array(text), depth: 0)
    }

    /// Strips inline Markdown to plain text (used for slugs and the outline).
    func renderPlainText(_ text: String) -> String {
        var result = ""
        let chars = Array(text)
        var index = 0
        while index < chars.count {
            let character = chars[index]
            if character == "\\", index + 1 < chars.count {
                result.append(chars[index + 1])
                index += 2
                continue
            }
            if "*_`~".contains(character) {
                index += 1
                continue
            }
            result.append(character)
            index += 1
        }
        return result
    }

    private func renderInline(_ chars: [Character], depth: Int) -> String {
        guard depth < 12 else { return escapeHTML(String(chars)) }
        var out = ""
        var index = 0
        let count = chars.count

        while index < count {
            let character = chars[index]

            switch character {
            case "\\":
                if index + 1 < count, isASCIIPunctuation(chars[index + 1]) {
                    out += escapeHTML(String(chars[index + 1]))
                    index += 2
                } else {
                    out += "\\"
                    index += 1
                }
            case "`":
                if let (html, next) = parseCodeSpan(chars, index) {
                    out += html
                    index = next
                } else {
                    out += "`"
                    index += 1
                }
            case "!":
                if index + 1 < count, chars[index + 1] == "[",
                   let (html, next) = parseLinkOrImage(chars, index, isImage: true, depth: depth) {
                    out += html
                    index = next
                } else {
                    out += "!"
                    index += 1
                }
            case "[":
                if let (html, next) = parseLinkOrImage(chars, index, isImage: false, depth: depth) {
                    out += html
                    index = next
                } else {
                    out += "["
                    index += 1
                }
            case "<":
                if let (html, next) = parseAutolink(chars, index) {
                    out += html
                    index = next
                } else {
                    out += "&lt;"
                    index += 1
                }
            case "&":
                out += "&amp;"
                index += 1
            case ">":
                out += "&gt;"
                index += 1
            case "\"":
                out += "&quot;"
                index += 1
            case "*", "_", "~":
                if let (html, next) = parseEmphasis(chars, index, depth: depth) {
                    out += html
                    index = next
                } else {
                    out += String(character)
                    index += 1
                }
            case "h":
                if let (html, next) = parseBareAutolink(chars, index) {
                    out += html
                    index = next
                } else {
                    out += "h"
                    index += 1
                }
            default:
                out += String(character)
                index += 1
            }
        }

        return out
    }

    private func parseCodeSpan(_ chars: [Character], _ start: Int) -> (String, Int)? {
        var ticks = 0
        var cursor = start
        while cursor < chars.count, chars[cursor] == "`" { ticks += 1; cursor += 1 }

        var search = cursor
        while search < chars.count {
            if chars[search] == "`" {
                var closing = 0
                var probe = search
                while probe < chars.count, chars[probe] == "`" { closing += 1; probe += 1 }
                if closing == ticks {
                    var content = String(chars[cursor..<search])
                    if content.hasPrefix(" "), content.hasSuffix(" "),
                       content.trimmingCharacters(in: .whitespaces).isEmpty == false {
                        content = String(content.dropFirst().dropLast())
                    }
                    return ("<code>\(escapeHTML(content))</code>", probe)
                }
                search = probe
            } else {
                search += 1
            }
        }
        return nil
    }

    private func parseLinkOrImage(_ chars: [Character], _ start: Int, isImage: Bool, depth: Int) -> (String, Int)? {
        let textStart = isImage ? start + 2 : start + 1
        var cursor = textStart
        var bracketDepth = 1
        while cursor < chars.count {
            let character = chars[cursor]
            if character == "\\" { cursor += 2; continue }
            if character == "[" { bracketDepth += 1 }
            if character == "]" {
                bracketDepth -= 1
                if bracketDepth == 0 { break }
            }
            cursor += 1
        }
        guard cursor < chars.count, bracketDepth == 0 else { return nil }
        let linkText = String(chars[textStart..<cursor])

        guard cursor + 1 < chars.count, chars[cursor + 1] == "(" else { return nil }
        var urlCursor = cursor + 2
        var url = ""
        var title: String?
        var parenDepth = 1
        while urlCursor < chars.count {
            let character = chars[urlCursor]
            if character == "\\", urlCursor + 1 < chars.count {
                url.append(chars[urlCursor + 1])
                urlCursor += 2
                continue
            }
            if character == "(" { parenDepth += 1 }
            if character == ")" {
                parenDepth -= 1
                if parenDepth == 0 { break }
            }
            if character == " " {
                // Possible title following the URL.
                let remainder = String(chars[urlCursor..<chars.count])
                if let parsed = parseLinkTitle(remainder) {
                    title = parsed.title
                    urlCursor += parsed.consumed
                    guard urlCursor < chars.count, chars[urlCursor] == ")" else { return nil }
                    break
                }
            }
            url.append(character)
            urlCursor += 1
        }
        guard urlCursor < chars.count, chars[urlCursor] == ")" else { return nil }

        let safeURL = sanitizeURL(url.trimmingCharacters(in: .whitespaces))
        let titleAttribute = title.map { " title=\"\(escapeAttribute($0))\"" } ?? ""

        if isImage {
            let alt = escapeAttribute(renderPlainText(linkText))
            return ("<img src=\"\(escapeAttribute(safeURL))\" alt=\"\(alt)\"\(titleAttribute)>", urlCursor + 1)
        }
        let innerHTML = renderInline(Array(linkText), depth: depth + 1)
        return ("<a href=\"\(escapeAttribute(safeURL))\"\(titleAttribute)>\(innerHTML)</a>", urlCursor + 1)
    }

    private func parseLinkTitle(_ remainder: String) -> (title: String, consumed: Int)? {
        let chars = Array(remainder)
        var index = 0
        while index < chars.count, chars[index] == " " { index += 1 }
        guard index < chars.count, chars[index] == "\"" || chars[index] == "'" else { return nil }
        let quote = chars[index]
        index += 1
        var title = ""
        while index < chars.count {
            if chars[index] == quote {
                return (title, index + 1)
            }
            title.append(chars[index])
            index += 1
        }
        return nil
    }

    private func parseAutolink(_ chars: [Character], _ start: Int) -> (String, Int)? {
        var cursor = start + 1
        var content = ""
        while cursor < chars.count, chars[cursor] != ">", chars[cursor] != " " {
            content.append(chars[cursor])
            cursor += 1
        }
        guard cursor < chars.count, chars[cursor] == ">" else { return nil }

        if content.contains("://"), sanitizeURL(content) == content {
            return ("<a href=\"\(escapeAttribute(content))\">\(escapeHTML(content))</a>", cursor + 1)
        }
        if content.contains("@"), !content.contains(" ") {
            return ("<a href=\"mailto:\(escapeAttribute(content))\">\(escapeHTML(content))</a>", cursor + 1)
        }
        return nil
    }

    private func parseBareAutolink(_ chars: [Character], _ start: Int) -> (String, Int)? {
        let remainder = String(chars[start...])
        guard remainder.hasPrefix("http://") || remainder.hasPrefix("https://") else { return nil }
        if start > 0 {
            let previous = chars[start - 1]
            if previous.isLetter || previous.isNumber { return nil }
        }
        var cursor = start
        while cursor < chars.count {
            let character = chars[cursor]
            if character == " " || character == "<" || character == "\"" { break }
            cursor += 1
        }
        var url = String(chars[start..<cursor])
        var trailing = ""
        while let last = url.last, ".,!?;:)".contains(last) {
            trailing = String(last) + trailing
            url.removeLast()
        }
        guard sanitizeURL(url) == url else { return nil }
        let html = "<a href=\"\(escapeAttribute(url))\">\(escapeHTML(url))</a>\(escapeHTML(trailing))"
        return (html, start + url.count + trailing.count)
    }

    private func parseEmphasis(_ chars: [Character], _ start: Int, depth: Int) -> (String, Int)? {
        let delimiter = chars[start]
        var runLength = 0
        var cursor = start
        while cursor < chars.count, chars[cursor] == delimiter { runLength += 1; cursor += 1 }

        let desired: Int
        if delimiter == "~" {
            guard runLength >= 2 else { return nil }
            desired = 2
        } else {
            desired = min(runLength, 3)
        }

        // Opening delimiter must be followed by a non-space "word".
        guard cursor < chars.count, chars[cursor] != " " else { return nil }

        // For underscores, avoid intra-word emphasis (snake_case).
        if delimiter == "_", start > 0 {
            let previous = chars[start - 1]
            if previous.isLetter || previous.isNumber { return nil }
        }

        var search = cursor
        while search < chars.count {
            if chars[search] == delimiter {
                var closing = 0
                var probe = search
                while probe < chars.count, chars[probe] == delimiter { closing += 1; probe += 1 }
                if closing >= desired, chars[search - 1] != " " {
                    if delimiter == "_", probe < chars.count {
                        let next = chars[probe]
                        if next.isLetter || next.isNumber {
                            search = probe
                            continue
                        }
                    }
                    let inner = Array(chars[cursor..<search])
                    let innerHTML = renderInline(inner, depth: depth + 1)
                    let wrapped = wrapEmphasis(innerHTML, delimiter: delimiter, length: desired)
                    return (wrapped, search + desired)
                }
                search = probe
            } else {
                search += 1
            }
        }
        return nil
    }

    private func wrapEmphasis(_ inner: String, delimiter: Character, length: Int) -> String {
        if delimiter == "~" {
            return "<del>\(inner)</del>"
        }
        switch length {
        case 1: return "<em>\(inner)</em>"
        case 2: return "<strong>\(inner)</strong>"
        default: return "<strong><em>\(inner)</em></strong>"
        }
    }

    // MARK: - Helpers

    private func leadingSpaces(_ line: String) -> Int {
        var count = 0
        for character in line {
            if character == " " { count += 1 }
            else if character == "\t" { count += 4 }
            else { break }
        }
        return count
    }

    private func isASCIIPunctuation(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else { return false }
        return "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~".unicodeScalars.contains(scalar)
    }

    /// Allows only safe URL schemes; anything else becomes an inert anchor.
    private func sanitizeURL(_ url: String) -> String {
        let lowered = url.lowercased()
        let blockedPrefixes = ["javascript:", "data:", "vbscript:", "file:"]
        for prefix in blockedPrefixes where lowered.hasPrefix(prefix) {
            return "#"
        }
        return url
    }

    private func escapeHTML(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            default: result.append(character)
            }
        }
        return result
    }

    private func escapeAttribute(_ text: String) -> String {
        escapeHTML(text).replacingOccurrences(of: "'", with: "&#39;")
    }
}
