// StrategyCanvasTab.swift — 策略画布 (WKWebView-based node editor)
// 使用轻量级 HTML/JS 节点编辑器，通过 WebKit 桥接与 Swift 通信

import SwiftUI
import WebKit

// MARK: - Main Canvas Tab
struct StrategyCanvasTab: View {
    @Environment(PulseColors.self) private var colors
    let strategy: Strategy
    let client: NetworkClientProtocol

    @State private var showCodePreview = false
    @State private var generatedCode = ""
    @State private var isDeploying = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CanvasWebView(
                strategy: strategy,
                client: client,
                onDeploy: { code in
                    generatedCode = code
                    showCodePreview = true
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(colors.background)
        }
        .sheet(isPresented: $showCodePreview) {
            CodePreviewSheet(code: generatedCode, onDeploy: {
                Task { await deployStrategy() }
            }, onCancel: {})
        }
    }

    private func deployStrategy() async {
        isDeploying = true
        defer { isDeploying = false }
        do {
            let api = APIStrategies(client: client)
            _ = try await api.deploy(id: strategy.id)
        } catch {
            // Silently fail — preview will show error or user can retry
        }
        showCodePreview = false
    }
}

// MARK: - Intermediate types for HTML graph conversion

/// Mirrors the JS graph format used in canvas-editor.html
private struct HTMLGraphNode: Codable {
    let id: String
    let type: String
    var name: String?
    var x: Double
    var y: Double
    var ports: HTMLPorts?
    var category: String?
}

private struct HTMLPorts: Codable {
    var `in`: [String]?
    var out: [String]?
}

private struct HTMLGraphEdge: Codable {
    let sourceNodeId: String
    let sourcePort: String
    let targetNodeId: String
    let targetPort: String
}

private struct HTMLGraph: Codable {
    let nodes: [HTMLGraphNode]
    let edges: [HTMLGraphEdge]
}

private extension WorkflowGraph {
    init(from htmlGraph: HTMLGraph) {
        var idMap: [String: UUID] = [:]
        for (_, node) in htmlGraph.nodes.enumerated() {
            idMap[node.id] = UUID()
        }

        self.nodes = htmlGraph.nodes.map { node in
            CanvasNode(
                id: idMap[node.id] ?? UUID(),
                nodeType: node.type,
                position: CGPoint(x: node.x, y: node.y),
                size: CGSize(width: 200, height: 120)
            )
        }

        self.edges = htmlGraph.edges.compactMap { edge in
            guard let srcId = idMap[edge.sourceNodeId],
                  let tgtId = idMap[edge.targetNodeId] else {
                return nil
            }
            return CanvasEdge(
                sourceNodeId: srcId,
                sourcePort: edge.sourcePort,
                targetNodeId: tgtId,
                targetPort: edge.targetPort,
                dataType: .signal
            )
        }

        self.groups = []
        self.viewport = ViewportState()
    }
}

// MARK: - WKWebView Representable
struct CanvasWebView: NSViewRepresentable {
    let strategy: Strategy
    let client: NetworkClientProtocol
    var onDeploy: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(strategy: strategy, client: client, onDeploy: onDeploy)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "canvasSave")
        config.userContentController.add(context.coordinator, name: "canvasDeploy")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        // Find the HTML file URL and load it with proper baseURL for local scripts
        let htmlURL: URL? = {
            #if swift(>=5.9)
            if let url = Bundle.module.url(forResource: "canvas-editor", withExtension: "html") {
                return url
            }
            #endif
            for dir in [Bundle.main.resourcePath ?? "", FileManager.default.currentDirectoryPath] {
                let url = URL(fileURLWithPath: dir).appendingPathComponent("canvas-editor.html")
                if FileManager.default.fileExists(atPath: url.path) { return url }
            }
            return nil
        }()

        if let url = htmlURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.loadHTMLString("<html><body style='background:#0A0A0B;color:white;display:flex;align-items:center;justify-content:center'><p>Canvas not found</p></body></html>", baseURL: nil)
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    // MARK: - Coordinator
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let strategy: Strategy
        let client: NetworkClientProtocol
        var onDeploy: ((String) -> Void)?
        weak var webView: WKWebView?
        private var saveWorkItem: DispatchWorkItem?
        private var didLoadGraph = false

        init(strategy: Strategy, client: NetworkClientProtocol, onDeploy: ((String) -> Void)?) {
            self.strategy = strategy
            self.client = client
            self.onDeploy = onDeploy
        }

        // MARK: - WKScriptMessageHandler
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "canvasSave":
                handleSave(message: message)
            case "canvasDeploy":
                handleDeploy(message: message)
            default:
                break
            }
        }

        private func handleSave(message: WKScriptMessage) {
            guard let json = message.body as? String else { return }
            saveWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                Task {
                    let api = APICanvas(client: self.client)
                    _ = try? await api.save(strategyId: self.strategy.id, graphJson: json)
                }
            }
            saveWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
        }

        private func handleDeploy(message: WKScriptMessage) {
            guard let json = message.body as? String else { return }
            do {
                // Parse HTML graph format and convert to WorkflowGraph
                let decoder = JSONDecoder()
                let htmlGraph = try decoder.decode(HTMLGraph.self, from: Data(json.utf8))
                let workflowGraph = WorkflowGraph(from: htmlGraph)
                let code = try CodeGenerator().generate(from: workflowGraph, strategyName: strategy.name)
                onDeploy?(code)
            } catch {
                onDeploy?("// Error: \(error.localizedDescription)")
            }
        }

        // MARK: - WKNavigationDelegate
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !didLoadGraph else { return }
            didLoadGraph = true
            Task { @MainActor in
                let api = APICanvas(client: client)
                if let response = try? await api.load(strategyId: strategy.id),
                   let data = response.graphJson.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) {
                    _ = try? await webView.callAsyncJavaScript(
                        "loadGraphJSON(data)",
                        arguments: ["data": json],
                        contentWorld: .page
                    )
                }
            }
        }
    }
}
