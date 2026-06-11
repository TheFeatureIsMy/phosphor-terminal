// CanvasWebView.swift — WKWebView wrapper for React Flow canvas

import SwiftUI
import WebKit

struct CanvasWebView: NSViewRepresentable {
    let viewModel: CanvasWebViewModel

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = config.userContentController
        contentController.add(context.coordinator, name: "canvas")

        let prefs = config.defaultWebpagePreferences
        prefs!.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")

        // canvas-web is copied as a directory (see Package.swift `.copy("Resources/canvas-web")`),
        // so the bundle contains canvas-web/index.html + canvas-web/assets/* with original layout,
        // and the HTML's relative `./assets/...` references resolve correctly.
        if let htmlURL = Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "canvas-web") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        } else {
            #if DEBUG
            print("[CanvasWebView] canvas-web/index.html not found in Bundle.module — verify Package.swift uses .copy(\"Resources/canvas-web\")")
            #endif
        }

        viewModel.webView = webView
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> CanvasBridge {
        CanvasBridge(viewModel: viewModel)
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: CanvasBridge) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "canvas")
    }
}
