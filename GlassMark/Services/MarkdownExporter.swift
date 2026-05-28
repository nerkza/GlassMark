import AppKit
import WebKit

/// Exports a rendered document to HTML or PDF via a save panel.
///
/// PDF generation needs a `WKWebView` to lay the document out, so an instance
/// retains itself in `active` until the asynchronous render completes.
@MainActor
final class MarkdownExporter: NSObject, WKNavigationDelegate {
    private static var active: [MarkdownExporter] = []

    private var webView: WKWebView?
    private var destinationURL: URL?

    static func exportHTML(_ html: String, suggestedName: String) {
        guard let url = savePanelURL(suggestedName: suggestedName, extension: "html") else { return }
        do {
            try html.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            presentError("Could not export HTML: \(error.localizedDescription)")
        }
    }

    static func exportPDF(html: String, baseURL: URL?, suggestedName: String) {
        guard let url = savePanelURL(suggestedName: suggestedName, extension: "pdf") else { return }
        let exporter = MarkdownExporter()
        active.append(exporter)
        exporter.generatePDF(html: html, baseURL: baseURL, destination: url)
    }

    private func generatePDF(html: String, baseURL: URL?, destination: URL) {
        destinationURL = destination
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 768, height: 1024), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let destinationURL else { finish(); return }
        // Allow layout to settle before snapshotting to PDF.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            webView.createPDF { result in
                switch result {
                case .success(let data):
                    do {
                        try data.write(to: destinationURL)
                    } catch {
                        Self.presentError("Could not write PDF: \(error.localizedDescription)")
                    }
                case .failure(let error):
                    Self.presentError("Could not export PDF: \(error.localizedDescription)")
                }
                self.finish()
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Self.presentError("Could not render document for export: \(error.localizedDescription)")
        finish()
    }

    private func finish() {
        webView = nil
        Self.active.removeAll { $0 === self }
    }

    private static func savePanelURL(suggestedName: String, extension fileExtension: String) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(suggestedName).\(fileExtension)"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    private static func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Export Failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
