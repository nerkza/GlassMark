import Foundation

struct MarkdownRenderService {
    func renderHTML(markdown: String, title: String) -> String {
        let body = markdown
            .components(separatedBy: .newlines)
            .map(renderLine)
            .joined(separator: "\n")

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(escapeHTML(title))</title>
          <style>
            :root { color-scheme: light dark; }
            body {
              font: -apple-system-body;
              line-height: 1.62;
              margin: 0;
              padding: 32px 42px;
              color: CanvasText;
              background: Canvas;
            }
            main { max-width: 780px; margin: 0 auto; }
            h1, h2, h3 { line-height: 1.2; margin: 1.35em 0 0.45em; }
            h1 { font-size: 2.1rem; }
            h2 { font-size: 1.55rem; }
            h3 { font-size: 1.25rem; }
            p { margin: 0.75em 0; }
            code, pre {
              font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
              background: color-mix(in srgb, CanvasText 8%, Canvas);
              border-radius: 6px;
            }
            code { padding: 0.12em 0.32em; }
            pre { padding: 14px 16px; overflow-x: auto; }
            blockquote {
              margin-left: 0;
              padding-left: 1rem;
              border-left: 3px solid color-mix(in srgb, CanvasText 24%, Canvas);
              color: color-mix(in srgb, CanvasText 72%, Canvas);
            }
            a { color: LinkText; }
          </style>
        </head>
        <body><main>
        \(body)
        </main></body>
        </html>
        """
    }

    private func renderLine(_ line: String) -> String {
        if line.hasPrefix("### ") {
            return "<h3>\(escapeInline(String(line.dropFirst(4))))</h3>"
        }
        if line.hasPrefix("## ") {
            return "<h2>\(escapeInline(String(line.dropFirst(3))))</h2>"
        }
        if line.hasPrefix("# ") {
            return "<h1>\(escapeInline(String(line.dropFirst(2))))</h1>"
        }
        if line.hasPrefix("> ") {
            return "<blockquote>\(escapeInline(String(line.dropFirst(2))))</blockquote>"
        }
        if line.hasPrefix("- ") {
            return "<p>• \(escapeInline(String(line.dropFirst(2))))</p>"
        }
        if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "<br>"
        }
        return "<p>\(escapeInline(line))</p>"
    }

    private func escapeInline(_ text: String) -> String {
        escapeHTML(text)
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
