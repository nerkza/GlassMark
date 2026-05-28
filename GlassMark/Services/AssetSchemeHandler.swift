import WebKit

/// Serves the preview WebView's resources over a custom URL scheme so the preview
/// works under the App Sandbox (where the WebContent process cannot read user
/// files directly). Two kinds of resource are served from the app process:
///
/// - **Bundled assets** (highlight.js, KaTeX + fonts, Mermaid) resolved by
///   filename from the app bundle.
/// - **Document-relative files** (e.g. images referenced by a Markdown file)
///   resolved against the current document's directory and read while holding the
///   workspace's security-scoped access.
///
/// Using this scheme as the preview's base URL also avoids a `file:` base URL that
/// the sandboxed WebContent process would be denied, which otherwise leaves the
/// preview blank.
@MainActor
final class AssetSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "glassmark-asset"
    static let shared = AssetSchemeHandler()

    private var documentDirectory: URL?
    private var securityScopeURL: URL?

    /// Point document-relative lookups at the active file's folder.
    func setDocumentContext(directory: URL?, securityScopeURL: URL?) {
        documentDirectory = directory
        self.securityScopeURL = securityScopeURL
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        let ext = (url.lastPathComponent as NSString).pathExtension
        guard let data = resolveData(for: url) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let headers = [
            "Content-Type": Self.mimeType(forExtension: ext),
            "Access-Control-Allow-Origin": "*",
            "Cache-Control": "no-cache"
        ]
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)
            ?? HTTPURLResponse()
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func resolveData(for url: URL) -> Data? {
        // 1. Bundled asset by filename (bundle resources are laid out flat).
        let filename = url.lastPathComponent
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        if !name.isEmpty,
           let bundleURL = Bundle.main.url(forResource: name, withExtension: ext),
           let data = try? Data(contentsOf: bundleURL) {
            return data
        }

        // 2. Document-relative file (e.g. an image), read under the security scope.
        guard let documentDirectory else { return nil }
        let relativePath = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
        guard !relativePath.isEmpty else { return nil }
        let fileURL = documentDirectory.appendingPathComponent(relativePath)

        let read: () -> Data? = { try? Data(contentsOf: fileURL) }
        if let scope = securityScopeURL {
            return URLSecurityScope.withAccess(to: scope, perform: read)
        }
        return read()
    }

    private static func mimeType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "js": return "application/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "woff2": return "font/woff2"
        case "woff": return "font/woff"
        case "ttf": return "font/ttf"
        case "json": return "application/json"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        default: return "application/octet-stream"
        }
    }
}
