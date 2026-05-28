import Foundation

/// Semantic classification of a Markdown token, mapped to text attributes by the
/// editor. Kept UI-agnostic so the tokenizer can be unit-tested in isolation.
enum MarkdownTokenStyle: Equatable {
    case heading(level: Int)
    case strong
    case emphasis
    case strikethrough
    case inlineCode
    case codeBlock
    case blockquote
    case listMarker
    case link
    case delimiter
}

struct MarkdownToken: Equatable {
    let range: NSRange
    let style: MarkdownTokenStyle
}

/// Produces a flat list of tokens describing Markdown syntax for editor
/// highlighting. Ranges are UTF-16 offsets compatible with `NSTextStorage`.
struct MarkdownSyntaxHighlighter {
    func tokens(in text: String) -> [MarkdownToken] {
        let nsText = text as NSString
        var tokens: [MarkdownToken] = []
        var offset = 0
        var insideFence = false
        var openFenceCharacter: Character = "`"

        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        for line in lines {
            let lineLength = (line as NSString).length
            let lineRange = NSRange(location: offset, length: lineLength)

            if let fence = fenceCharacter(of: line) {
                tokens.append(MarkdownToken(range: lineRange, style: .codeBlock))
                if insideFence {
                    if fence == openFenceCharacter { insideFence = false }
                } else {
                    insideFence = true
                    openFenceCharacter = fence
                }
                offset += lineLength + 1
                continue
            }

            if insideFence {
                tokens.append(MarkdownToken(range: lineRange, style: .codeBlock))
                offset += lineLength + 1
                continue
            }

            appendBlockTokens(line: line, lineStart: offset, into: &tokens)
            appendInlineTokens(line: line, lineStart: offset, into: &tokens)

            offset += lineLength + 1
        }

        // Keep ranges within bounds in case of trailing-newline arithmetic.
        let total = nsText.length
        return tokens.filter { $0.range.location + $0.range.length <= total }
    }

    private func fenceCharacter(of line: String) -> Character? {
        let trimmed = line.drop(while: { $0 == " " })
        guard let first = trimmed.first, first == "`" || first == "~" else { return nil }
        let count = trimmed.prefix(while: { $0 == first }).count
        return count >= 3 ? first : nil
    }

    private func appendBlockTokens(line: String, lineStart: Int, into tokens: inout [MarkdownToken]) {
        let nsLine = line as NSString
        let indent = line.prefix(while: { $0 == " " }).count

        // Headings.
        let afterIndent = Array(line.dropFirst(indent))
        var level = 0
        while level < afterIndent.count, afterIndent[level] == "#" { level += 1 }
        if level >= 1, level <= 6, level < afterIndent.count, afterIndent[level] == " " {
            tokens.append(MarkdownToken(range: NSRange(location: lineStart, length: nsLine.length), style: .heading(level: level)))
            return
        }

        // Blockquote.
        if afterIndent.first == ">" {
            tokens.append(MarkdownToken(range: NSRange(location: lineStart, length: nsLine.length), style: .blockquote))
            return
        }

        // List markers (unordered and ordered).
        if afterIndent.count >= 2 {
            let first = afterIndent[0]
            if (first == "-" || first == "*" || first == "+"), afterIndent[1] == " " {
                let markerStart = lineStart + (String(line.prefix(indent)) as NSString).length
                tokens.append(MarkdownToken(range: NSRange(location: markerStart, length: 1), style: .listMarker))
            } else if first.isNumber {
                var cursor = 0
                while cursor < afterIndent.count, afterIndent[cursor].isNumber { cursor += 1 }
                if cursor < afterIndent.count, afterIndent[cursor] == "." || afterIndent[cursor] == ")",
                   cursor + 1 < afterIndent.count, afterIndent[cursor + 1] == " " {
                    let markerStart = lineStart + (String(line.prefix(indent)) as NSString).length
                    tokens.append(MarkdownToken(range: NSRange(location: markerStart, length: cursor + 1), style: .listMarker))
                }
            }
        }
    }

    private func appendInlineTokens(line: String, lineStart: Int, into tokens: inout [MarkdownToken]) {
        let chars = Array(line)
        var index = 0
        var utf16Offset = 0

        func utf16Length(_ range: ClosedRange<Int>) -> Int {
            chars[range].reduce(0) { $0 + String($1).utf16.count }
        }

        while index < chars.count {
            let character = chars[index]
            let characterUTF16 = String(character).utf16.count

            switch character {
            case "`":
                if let end = matchRun(chars, from: index, character: "`") {
                    let length = utf16Length(index...end)
                    tokens.append(MarkdownToken(range: NSRange(location: lineStart + utf16Offset, length: length), style: .inlineCode))
                    utf16Offset += length
                    index = end + 1
                    continue
                }
            case "*", "_", "~":
                if let (end, style) = matchEmphasis(chars, from: index) {
                    let length = utf16Length(index...end)
                    tokens.append(MarkdownToken(range: NSRange(location: lineStart + utf16Offset, length: length), style: style))
                    utf16Offset += length
                    index = end + 1
                    continue
                }
            case "[":
                if let end = matchLink(chars, from: index) {
                    let length = utf16Length(index...end)
                    tokens.append(MarkdownToken(range: NSRange(location: lineStart + utf16Offset, length: length), style: .link))
                    utf16Offset += length
                    index = end + 1
                    continue
                }
            default:
                break
            }

            utf16Offset += characterUTF16
            index += 1
        }
    }

    /// Finds the end index of a delimiter run starting at `from` (e.g. a code span).
    private func matchRun(_ chars: [Character], from start: Int, character: Character) -> Int? {
        var ticks = 0
        var cursor = start
        while cursor < chars.count, chars[cursor] == character { ticks += 1; cursor += 1 }
        var search = cursor
        while search < chars.count {
            if chars[search] == character {
                var closing = 0
                var probe = search
                while probe < chars.count, chars[probe] == character { closing += 1; probe += 1 }
                if closing == ticks { return probe - 1 }
                search = probe
            } else {
                search += 1
            }
        }
        return nil
    }

    private func matchEmphasis(_ chars: [Character], from start: Int) -> (end: Int, style: MarkdownTokenStyle)? {
        let delimiter = chars[start]
        var runLength = 0
        var cursor = start
        while cursor < chars.count, chars[cursor] == delimiter { runLength += 1; cursor += 1 }
        guard cursor < chars.count, chars[cursor] != " " else { return nil }

        let desired = delimiter == "~" ? 2 : min(runLength, 2)
        if delimiter == "~", runLength < 2 { return nil }

        var search = cursor
        while search < chars.count {
            if chars[search] == delimiter, chars[search - 1] != " " {
                var closing = 0
                var probe = search
                while probe < chars.count, chars[probe] == delimiter { closing += 1; probe += 1 }
                if closing >= desired {
                    let style: MarkdownTokenStyle
                    if delimiter == "~" { style = .strikethrough }
                    else { style = desired >= 2 ? .strong : .emphasis }
                    return (probe - 1, style)
                }
                search = probe
            } else {
                search += 1
            }
        }
        return nil
    }

    private func matchLink(_ chars: [Character], from start: Int) -> Int? {
        var cursor = start + 1
        var depth = 1
        while cursor < chars.count {
            if chars[cursor] == "[" { depth += 1 }
            if chars[cursor] == "]" { depth -= 1; if depth == 0 { break } }
            cursor += 1
        }
        guard cursor < chars.count, cursor + 1 < chars.count, chars[cursor + 1] == "(" else { return nil }
        var urlCursor = cursor + 2
        while urlCursor < chars.count, chars[urlCursor] != ")" { urlCursor += 1 }
        guard urlCursor < chars.count, chars[urlCursor] == ")" else { return nil }
        return urlCursor
    }
}
