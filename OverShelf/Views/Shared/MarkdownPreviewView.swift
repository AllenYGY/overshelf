import SwiftUI
import WebKit

/// A WebKit-backed Markdown preview with local Marked.js and KaTeX support.
struct MarkdownPreviewView: NSViewRepresentable {
    let markdown: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = true
        context.coordinator.pendingMarkdown = markdown

        if let url = Bundle.main.url(forResource: "markdown", withExtension: "html", subdirectory: "Markdown") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.update(markdown: markdown, in: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var pendingMarkdown: String?
        private var didFinishLoading = false

        func update(markdown: String, in webView: WKWebView) {
            pendingMarkdown = markdown
            if didFinishLoading {
                render(markdown, in: webView)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            didFinishLoading = true
            if let markdown = pendingMarkdown {
                render(markdown, in: webView)
            }
        }

        private func render(_ markdown: String, in webView: WKWebView) {
            guard let data = try? JSONSerialization.data(withJSONObject: [markdown]),
                  let json = String(data: data, encoding: .utf8) else {
                return
            }
            let escaped = json.dropFirst().dropLast()
            webView.evaluateJavaScript("renderMarkdown(\(escaped), true);")
        }
    }
}
