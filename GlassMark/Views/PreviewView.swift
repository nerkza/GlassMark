import SwiftUI
import WebKit

struct PreviewView: View {
    @EnvironmentObject private var documentStore: DocumentStore

    private let renderService = MarkdownRenderService()

    var body: some View {
        if let document = documentStore.document {
            let html = renderService.renderHTML(markdown: document.text, title: document.file.name)
            WebPreview(html: html, baseURL: document.file.url.deletingLastPathComponent())
        } else {
            ContentUnavailableView("Nothing to Preview", systemImage: "doc.text.magnifyingglass")
        }
    }
}

private struct WebPreview: NSViewRepresentable {
    let html: String
    let baseURL: URL

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: baseURL)
    }
}
