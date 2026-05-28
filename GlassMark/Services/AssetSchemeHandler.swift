import WebKit

/// Serves vendored web assets (highlight.js, KaTeX, Mermaid, fonts) to the preview
/// WebView from the app bundle over a custom URL scheme, so the preview renders
/// code, math, and diagrams entirely offline.
///
/// Assets are resolved by filename, which is robust to however the bundle lays
/// them out, and responses include permissive CORS headers so `@font-face` files
/// load from the custom scheme.
final class AssetSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "glassmark-asset"
    static let shared = AssetSchemeHandler()

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        let filename = url.lastPathComponent
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension

        guard !name.isEmpty,
              let fileURL = Bundle.main.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: fileURL) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let headers = [
            "Content-Type": Self.mimeType(forExtension: ext),
            "Access-Control-Allow-Origin": "*",
            "Cache-Control": "max-age=86400"
        ]
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)
            ?? HTTPURLResponse()
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private static func mimeType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "js": return "application/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "woff2": return "font/woff2"
        case "woff": return "font/woff"
        case "ttf": return "font/ttf"
        case "json": return "application/json"
        default: return "application/octet-stream"
        }
    }
}
