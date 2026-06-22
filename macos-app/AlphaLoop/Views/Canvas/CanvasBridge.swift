// CanvasBridge.swift — WKScriptMessageHandler bridging React ↔ Swift

import WebKit

final class CanvasBridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    let viewModel: CanvasWebViewModel

    init(viewModel: CanvasWebViewModel) {
        self.viewModel = viewModel
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        Task { @MainActor in
            switch type {
            case "canvasReady":
                await viewModel.onCanvasReady()

            case "graphChanged":
                if let payload = body["payload"] as? [String: Any] {
                    viewModel.onGraphChanged(payload: payload)
                }

            case "requestValidation":
                if let payload = body["payload"] as? [String: Any],
                   let dsl = payload["dsl"] as? [String: Any] {
                    await viewModel.validateAndSendResult(dsl: dsl)
                }

            case "requestSaveVersion":
                if let payload = body["payload"] as? [String: Any],
                   let dsl = payload["dsl"] as? [String: Any] {
                    await viewModel.saveVersion(dsl: dsl)
                }

            case "selectionChanged":
                // canvas-web sends {type:'selectionChanged', selectedNode:{...}|null} (flat, no payload wrapper)
                viewModel.onSelectionChanged(payload: body)

            case "graphStats":
                // canvas-web sends {type:'graphStats', nodeCount, edgeCount, validation} (flat)
                viewModel.onGraphStats(payload: body)

            default:
                break
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // WebView finished loading HTML
    }
}
