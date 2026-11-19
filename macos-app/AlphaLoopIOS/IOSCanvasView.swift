import SwiftUI
import WebKit

/// Read-only DAG view. The canvas bundle is the same React build used by the
/// macOS WebView; the DSL is injected through the existing JS bridge.
struct IOSCanvasView: UIViewRepresentable {
    let dsl: [String: AnyCodable]

    func makeCoordinator() -> Coordinator { Coordinator(dsl: dsl) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear

        guard let index = Bundle.main.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "canvas-web"
        ) else {
            context.coordinator.missingBundle = true
            return webView
        }
        webView.loadFileURL(index, allowingReadAccessTo: index.deletingLastPathComponent())
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.dsl = dsl
        context.coordinator.injectIfPossible(webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var dsl: [String: AnyCodable]
        var missingBundle = false
        private var injected = false

        init(dsl: [String: AnyCodable]) {
            self.dsl = dsl
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injected = false
            injectIfPossible(webView)
        }

        func injectIfPossible(_ webView: WKWebView) {
            guard !injected, !missingBundle else { return }
            guard let data = try? JSONEncoder().encode(dsl),
                  let json = String(data: data, encoding: .utf8) else { return }
            let script = """
            (function () {
              const dsl = \(json);
              function send() {
                if (!window.bridge) { setTimeout(send, 150); return; }
                window.bridge.receive({ type: 'loadDSL', payload: { dsl: dsl } });
                window.bridge.receive({ type: 'setReadOnly', readOnly: true });
              }
              send();
            })();
            """
            webView.evaluateJavaScript(script)
            injected = true
        }
    }
}

struct IOSCanvasScreen: View {
    let title: String
    let dsl: [String: AnyCodable]

    var body: some View {
        IOSCanvasView(dsl: dsl)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}
