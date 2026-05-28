import Foundation

/// Produces the HTML shown in the preview pane and used for export.
///
/// The preview uses a persistent WebView: `documentShell` is loaded once and the
/// rendered body is swapped in via JavaScript, which avoids the flicker and
/// scroll-jumping of reloading the whole document on every keystroke.
struct MarkdownRenderService {
    private let renderer = MarkdownHTMLRenderer()

    /// Rendered inner HTML (frontmatter + body) injected into the preview shell.
    func renderBody(markdown: String) -> String {
        let (frontmatter, content) = splitFrontmatter(markdown)
        let frontmatterHTML = frontmatter.map(renderFrontmatter) ?? ""
        return frontmatterHTML + renderer.renderBody(content)
    }

    /// Like `renderBody` but tags top-level blocks with `data-line` (offset past
    /// any frontmatter) for line-mapped scroll sync in the preview.
    func renderPreviewBody(markdown: String) -> String {
        let (frontmatter, content) = splitFrontmatter(markdown)
        let frontmatterHTML = frontmatter.map(renderFrontmatter) ?? ""
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let contentNormalized = content.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lineOffset = normalized.components(separatedBy: "\n").count - contentNormalized.components(separatedBy: "\n").count
        return frontmatterHTML + renderer.renderBody(content, withSourceLines: true, lineOffset: max(0, lineOffset))
    }

    /// Static page loaded once into the preview WebView.
    func documentShell(title: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(escape(title))</title>
          <style>\(Self.css)</style>
          <style id="userTheme"></style>
        </head>
        <body>
          <main id="content"></main>
          <script>\(Self.script)</script>
        </body>
        </html>
        """
    }

    /// Combined theme + custom CSS injected into the preview via `setTheme`.
    func themeCSS(_ theme: PreviewTheme, customCSS: String) -> String {
        [theme.css, customCSS].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// Complete standalone document, used for HTML/PDF export and tests.
    func fullHTML(markdown: String, title: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(escape(title))</title>
          <style>\(Self.css)</style>
        </head>
        <body>
          <main id="content">
        \(renderBody(markdown: markdown))
          </main>
        </body>
        </html>
        """
    }

    // MARK: - Frontmatter

    /// Splits a leading `---` fenced YAML block from the document body.
    func splitFrontmatter(_ markdown: String) -> (frontmatter: [(String, String)]?, body: String) {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n") else { return (nil, markdown) }

        let lines = normalized.components(separatedBy: "\n")
        var closingIndex: Int?
        for index in 1..<lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed == "---" || trimmed == "..." {
                closingIndex = index
                break
            }
        }

        guard let closingIndex else { return (nil, markdown) }

        var pairs: [(String, String)] = []
        for index in 1..<closingIndex {
            let line = lines[index]
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
            var value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")),
               value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }
            if !key.isEmpty { pairs.append((key, value)) }
        }

        let body = lines[(closingIndex + 1)...].joined(separator: "\n")
        return (pairs.isEmpty ? nil : pairs, body)
    }

    private func renderFrontmatter(_ pairs: [(String, String)]) -> String {
        var rows = ""
        for (key, value) in pairs {
            rows += "<tr><th>\(escape(key))</th><td>\(escape(value))</td></tr>\n"
        }
        return "<div class=\"frontmatter\"><table>\n\(rows)</table></div>\n"
    }

    private func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - Assets

    private static let script = """
    var suppressScroll = false;
    function setContent(html) {
      var main = document.getElementById('content');
      var doc = document.scrollingElement || document.documentElement;
      var previousMax = doc.scrollHeight - doc.clientHeight;
      var ratio = previousMax > 0 ? doc.scrollTop / previousMax : 0;
      suppressScroll = true;
      main.innerHTML = html;
      requestAnimationFrame(function () {
        var newMax = doc.scrollHeight - doc.clientHeight;
        doc.scrollTop = ratio * newMax;
        setTimeout(function () { suppressScroll = false; }, 60);
      });
    }
    function absoluteTop(el) {
      var doc = document.scrollingElement || document.documentElement;
      return el.getBoundingClientRect().top + doc.scrollTop;
    }
    function scrollToLine(line) {
      suppressScroll = true;
      var els = document.querySelectorAll('[data-line]');
      var target = null;
      for (var i = 0; i < els.length; i++) {
        var l = parseInt(els[i].getAttribute('data-line'), 10);
        if (l <= line) { target = els[i]; } else { break; }
      }
      var doc = document.scrollingElement || document.documentElement;
      doc.scrollTop = target ? Math.max(0, absoluteTop(target) - 8) : 0;
      setTimeout(function () { suppressScroll = false; }, 90);
    }
    function scrollToHeading(ordinal) {
      var headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
      if (ordinal >= 0 && ordinal < headings.length) {
        headings[ordinal].scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    }
    function setTheme(css) {
      var el = document.getElementById('userTheme');
      if (el) { el.textContent = css; }
    }
    window.addEventListener('scroll', function () {
      if (suppressScroll) return;
      var doc = document.scrollingElement || document.documentElement;
      var top = doc.scrollTop;
      var els = document.querySelectorAll('[data-line]');
      var line = 0;
      for (var i = 0; i < els.length; i++) {
        if (absoluteTop(els[i]) <= top + 1) {
          line = parseInt(els[i].getAttribute('data-line'), 10);
        } else { break; }
      }
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.glassmarkScroll) {
        window.webkit.messageHandlers.glassmarkScroll.postMessage(line);
      }
    }, { passive: true });
    """

    static let css = """
    :root { color-scheme: light dark; }
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
      font-size: 16px;
      line-height: 1.62;
      margin: 0;
      padding: 0;
      color: CanvasText;
      background: transparent;
      -webkit-font-smoothing: antialiased;
    }
    main {
      max-width: 760px;
      margin: 0 auto;
      padding: 40px 44px 96px;
    }
    h1, h2, h3, h4, h5, h6 {
      line-height: 1.25;
      margin: 1.6em 0 0.5em;
      font-weight: 600;
    }
    h1 { font-size: 2.0rem; }
    h2 {
      font-size: 1.55rem;
      padding-bottom: 0.3em;
      border-bottom: 1px solid color-mix(in srgb, CanvasText 14%, transparent);
    }
    h3 { font-size: 1.27rem; }
    h4 { font-size: 1.08rem; }
    h5, h6 { font-size: 1rem; color: color-mix(in srgb, CanvasText 72%, Canvas); }
    p { margin: 0.85em 0; }
    a { color: color-mix(in srgb, LinkText 88%, CanvasText); text-decoration: none; }
    a:hover { text-decoration: underline; }
    ul, ol { margin: 0.7em 0; padding-left: 1.7em; }
    li { margin: 0.28em 0; }
    li > ul, li > ol { margin: 0.2em 0; }
    ul.contains-task-list { list-style: none; padding-left: 1.1em; }
    li.task-list-item { list-style: none; }
    li.task-list-item input { margin-right: 0.5em; transform: translateY(1px); }
    code, pre {
      font-family: ui-monospace, "SF Mono", SFMono-Regular, Menlo, monospace;
      font-size: 0.9em;
    }
    code {
      background: color-mix(in srgb, CanvasText 9%, Canvas);
      border-radius: 5px;
      padding: 0.15em 0.38em;
    }
    pre {
      background: color-mix(in srgb, CanvasText 6%, Canvas);
      border: 1px solid color-mix(in srgb, CanvasText 10%, transparent);
      border-radius: 9px;
      padding: 14px 16px;
      overflow-x: auto;
      line-height: 1.5;
    }
    pre code { background: none; padding: 0; border-radius: 0; }
    blockquote {
      margin: 1em 0;
      padding: 0.1em 1.1em;
      border-left: 3px solid color-mix(in srgb, CanvasText 26%, Canvas);
      color: color-mix(in srgb, CanvasText 74%, Canvas);
    }
    hr {
      border: none;
      height: 1px;
      background: color-mix(in srgb, CanvasText 16%, transparent);
      margin: 2em 0;
    }
    table {
      border-collapse: collapse;
      margin: 1.1em 0;
      display: block;
      overflow-x: auto;
    }
    th, td {
      border: 1px solid color-mix(in srgb, CanvasText 18%, transparent);
      padding: 7px 13px;
    }
    th { background: color-mix(in srgb, CanvasText 7%, Canvas); font-weight: 600; }
    tr:nth-child(even) td { background: color-mix(in srgb, CanvasText 3%, Canvas); }
    img { max-width: 100%; border-radius: 8px; }
    sup.footnote-ref { font-size: 0.72em; line-height: 0; }
    sup.footnote-ref a { text-decoration: none; padding: 0 0.15em; }
    .footnotes { margin-top: 3em; font-size: 0.9em; color: color-mix(in srgb, CanvasText 78%, Canvas); }
    .footnotes hr { margin-bottom: 1.2em; }
    .footnote-back { text-decoration: none; padding-left: 0.3em; }
    .frontmatter {
      margin: 0 0 1.4em;
      padding: 4px 16px;
      background: color-mix(in srgb, CanvasText 5%, Canvas);
      border: 1px solid color-mix(in srgb, CanvasText 12%, transparent);
      border-radius: 10px;
    }
    .frontmatter table { display: table; width: 100%; margin: 8px 0; }
    .frontmatter th, .frontmatter td { border: none; padding: 4px 10px; text-align: left; vertical-align: top; }
    .frontmatter th {
      background: none;
      color: color-mix(in srgb, CanvasText 60%, Canvas);
      font-weight: 600;
      width: 1%;
      white-space: nowrap;
      font-size: 0.86em;
      text-transform: uppercase;
      letter-spacing: 0.03em;
    }
    """
}
