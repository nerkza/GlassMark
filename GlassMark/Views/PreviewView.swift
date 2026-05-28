import AppKit
import SwiftUI
import WebKit

struct PreviewView: View {
    @EnvironmentObject private var documentStore: DocumentStore
    @EnvironmentObject private var commandStore: CommandStore
    @EnvironmentObject private var preferencesStore: PreferencesStore

    private let renderService = MarkdownRenderService()

    var body: some View {
        if let document = documentStore.document {
            WebPreview(
                markdown: document.text,
                title: document.file.name,
                baseURL: document.file.url.deletingLastPathComponent(),
                scopeURL: document.workspaceRootURL,
                themeCSS: renderService.themeCSS(preferencesStore.previewTheme, customCSS: preferencesStore.customPreviewCSS),
                scrollRequest: commandStore.outlineScrollRequest,
                scrollSync: commandStore.scrollSync,
                onScroll: { commandStore.publishScroll(line: $0, source: .preview) }
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
    let scopeURL: URL
    let themeCSS: String
    let scrollRequest: OutlineScrollRequest?
    let scrollSync: ScrollSync?
    let onScroll: (Int) -> Void

    private let renderService = MarkdownRenderService()

    func makeCoordinator() -> Coordinator {
        Coordinator(renderService: renderService)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.userContentController.add(context.coordinator, name: "glassmarkScroll")
        configuration.setURLSchemeHandler(AssetSchemeHandler.shared, forURLScheme: AssetSchemeHandler.scheme)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        context.coordinator.onScroll = onScroll

        AssetSchemeHandler.shared.setDocumentContext(directory: baseURL, securityScopeURL: scopeURL)
        // Use the custom scheme (not file://) as the base URL so the sandboxed
        // WebContent process can commit the page and resolve resources.
        webView.loadHTMLString(
            renderService.documentShell(title: title),
            baseURL: URL(string: "\(AssetSchemeHandler.scheme)://app/")
        )
        context.coordinator.applyTheme(themeCSS)
        context.coordinator.scheduleRender(markdown: markdown)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        AssetSchemeHandler.shared.setDocumentContext(directory: baseURL, securityScopeURL: scopeURL)
        context.coordinator.onScroll = onScroll
        context.coordinator.applyTheme(themeCSS)
        context.coordinator.scheduleRender(markdown: markdown)
        context.coordinator.handleScroll(request: scrollRequest)
        context.coordinator.handleScrollSync(scrollSync)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var onScroll: ((Int) -> Void)?
        private let renderService: MarkdownRenderService
        private var isShellLoaded = false
        private var pendingMarkdown: String?
        private var latestMarkdown: String = ""
        private var renderWorkItem: DispatchWorkItem?
        private var lastHandledScrollID: UUID?
        private var lastHandledSyncToken: Int?
        private var appliedTheme: String?

        init(renderService: MarkdownRenderService) {
            self.renderService = renderService
        }

        func applyTheme(_ css: String) {
            guard appliedTheme != css else { return }
            appliedTheme = css
            guard isShellLoaded else { return }
            inject(theme: css)
        }

        private func inject(theme css: String) {
            guard let webView,
                  let data = try? JSONSerialization.data(withJSONObject: [css]),
                  let json = String(data: data, encoding: .utf8) else { return }
            let literal = String(json.dropFirst().dropLast())
            webView.evaluateJavaScript("setTheme(\(literal));", completionHandler: nil)
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

        func handleScrollSync(_ sync: ScrollSync?) {
            guard let sync, sync.source == .editor, lastHandledSyncToken != sync.token else { return }
            lastHandledSyncToken = sync.token
            webView?.evaluateJavaScript("scrollToLine(\(sync.line));", completionHandler: nil)
        }

        nonisolated func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            // Script messages are always delivered on the main thread.
            MainActor.assumeIsolated {
                guard let line = (message.body as? NSNumber)?.intValue else { return }
                onScroll?(line)
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
                    let body = service.renderPreviewBody(markdown: markdown)
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
            if let appliedTheme {
                inject(theme: appliedTheme)
            }
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
