import AppKit
import SwiftUI
import WebKit

struct PreviewView: View {
    @EnvironmentObject private var documentStore: DocumentStore
    @EnvironmentObject private var commandStore: CommandStore

    var body: some View {
        if let document = documentStore.document {
            WebPreview(
                markdown: document.text,
                title: document.file.name,
                baseURL: document.file.url.deletingLastPathComponent(),
                scrollRequest: commandStore.outlineScrollRequest
            )
        } else {
            ContentUnavailableView("Nothing to Preview", systemImage: "doc.text.magnifyingglass")
        }
    }
}

/// A persistent WebView preview. The HTML shell loads once; rendered Markdown is
/// swapped in via JavaScript (debounced, off-main-thread render) so editing stays
/// smooth and the scroll position is preserved between updates.
private struct WebPreview: NSViewRepresentable {
    let markdown: String
    let title: String
    let baseURL: URL
    let scrollRequest: OutlineScrollRequest?

    private let renderService = MarkdownRenderService()

    func makeCoordinator() -> Coordinator {
        Coordinator(renderService: renderService)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView

        webView.loadHTMLString(renderService.documentShell(title: title), baseURL: baseURL)
        context.coordinator.scheduleRender(markdown: markdown)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.scheduleRender(markdown: markdown)
        context.coordinator.handleScroll(request: scrollRequest)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        private let renderService: MarkdownRenderService
        private var isShellLoaded = false
        private var pendingMarkdown: String?
        private var latestMarkdown: String = ""
        private var renderWorkItem: DispatchWorkItem?
        private var lastHandledScrollID: UUID?

        init(renderService: MarkdownRenderService) {
            self.renderService = renderService
        }

        func handleScroll(request: OutlineScrollRequest?) {
            guard let request, lastHandledScrollID != request.id else { return }
            lastHandledScrollID = request.id
            let ordinal = request.headingOrdinal
            // Defer slightly so any pending content update is applied first.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.webView?.evaluateJavaScript("scrollToHeading(\(ordinal));", completionHandler: nil)
            }
        }

        func scheduleRender(markdown: String) {
            guard markdown != latestMarkdown else { return }
            latestMarkdown = markdown

            renderWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                let service = self.renderService
                DispatchQueue.global(qos: .userInitiated).async {
                    let body = service.renderBody(markdown: markdown)
                    DispatchQueue.main.async {
                        self.apply(body: body)
                    }
                }
            }
            renderWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
        }

        private func apply(body: String) {
            guard isShellLoaded else {
                pendingMarkdown = body
                return
            }
            inject(body: body)
        }

        private func inject(body: String) {
            guard let webView,
                  let data = try? JSONSerialization.data(withJSONObject: [body]),
                  let json = String(data: data, encoding: .utf8) else { return }
            // json is a one-element array; drop the brackets to get the quoted string literal.
            let literal = String(json.dropFirst().dropLast())
            webView.evaluateJavaScript("setContent(\(literal));", completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isShellLoaded = true
            if let pendingMarkdown {
                self.pendingMarkdown = nil
                inject(body: pendingMarkdown)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                return .allow
            }

            // Open external links in the user's browser; allow in-page anchors.
            if let scheme = url.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme) {
                NSWorkspace.shared.open(url)
                return .cancel
            }
            return .allow
        }
    }
}
