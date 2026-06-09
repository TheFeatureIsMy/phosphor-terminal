// CanvasWebViewModel.swift — manages WebView canvas state, DSL validation, version save

import SwiftUI
import WebKit

@Observable
@MainActor
final class CanvasWebViewModel {
    var isReady = false
    var lastDSL: [String: Any]?
    var lastGraphState: String?
    var validationValid: Bool?
    var validationErrors: Int = 0
    var isSaving = false
    var saveSuccess = false
    var error: String?

    weak var webView: WKWebView?
    var errorHandler: ErrorHandler?

    private let api: APIStrategiesV2
    let strategyId: String
    private var pendingDSL: [String: Any]?

    init(strategyId: String, client: NetworkClientProtocol) {
        self.strategyId = strategyId
        self.api = APIStrategiesV2(client: client)
    }

    func onCanvasReady() async {
        isReady = true
        if let dsl = pendingDSL {
            sendDSLToCanvas(dsl)
            pendingDSL = nil
        }
    }

    func onGraphChanged(payload: [String: Any]) {
        if let dsl = payload["dsl"] as? [String: Any] {
            lastDSL = dsl
        }
        if let graphState = payload["graphState"] as? String {
            lastGraphState = graphState
        }
        validationValid = nil
        validationErrors = 0
        saveSuccess = false
    }

    func validateAndSendResult(dsl: [String: Any]) async {
        do {
            nonisolated(unsafe) let safeDsl = dsl
            let report = try await api.validateDSL(safeDsl)
            validationValid = report.valid
            validationErrors = report.errorCount
            let reportDict = encodeValidationReport(report)
            let msg: [String: Any] = ["type": "validationResult", "payload": reportDict]
            sendMessageToCanvas(msg)
        } catch {
            errorHandler?.handle(error, context: "验证 DSL")
            self.error = error.localizedDescription
        }
    }

    func saveVersion(dsl: [String: Any]) async {
        isSaving = true
        saveSuccess = false
        defer { isSaving = false }

        do {
            nonisolated(unsafe) let safeDsl = dsl
            let report = try await api.validateDSL(safeDsl)
            if !report.valid {
                let reportDict = encodeValidationReport(report)
                let msg: [String: Any] = ["type": "validationResult", "payload": reportDict]
                sendMessageToCanvas(msg)
                validationValid = false
                validationErrors = report.errorCount
                return
            }

            nonisolated(unsafe) let saveDsl = dsl
            _ = try await api.createVersion(strategyId: strategyId, ruleDsl: saveDsl)
            saveSuccess = true
            validationValid = true
            validationErrors = 0
        } catch {
            errorHandler?.handle(error, context: "保存版本")
            self.error = error.localizedDescription
        }
    }

    func sendMTFGuardStateUpdate(guardId: String, state: String, action: String, reasonCodes: [String]) {
        let msg: [String: Any] = [
            "type": "mtfGuardStateUpdate",
            "payload": [
                "guardId": guardId,
                "state": state,
                "action": action,
                "reasonCodes": reasonCodes,
            ],
        ]
        sendMessageToCanvas(msg)
    }

    func loadDSL(_ dsl: [String: Any]) {
        if isReady {
            sendDSLToCanvas(dsl)
        } else {
            pendingDSL = dsl
        }
    }

    private func sendDSLToCanvas(_ dsl: [String: Any]) {
        let msg: [String: Any] = ["type": "loadDSL", "payload": ["dsl": dsl]]
        sendMessageToCanvas(msg)
    }

    private func sendMessageToCanvas(_ msg: [String: Any]) {
        guard let webView else { return }
        do {
            let data = try JSONSerialization.data(withJSONObject: msg)
            if let json = String(data: data, encoding: .utf8) {
                let js = "window.bridge.receive(\(json))"
                webView.evaluateJavaScript(js) { _, error in
                    if let error {
                        print("[CanvasWebVM] JS error: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("[CanvasWebVM] JSON serialization error: \(error)")
        }
    }

    private func encodeValidationReport(_ report: DSLValidationReport) -> [String: Any] {
        var errors: [[String: Any]] = []
        for e in report.errors {
            errors.append(["code": e.code, "path": e.path, "message": e.message, "severity": e.severity])
        }
        var warnings: [[String: Any]] = []
        for w in report.warnings {
            warnings.append(["code": w.code, "path": w.path, "message": w.message, "severity": w.severity])
        }
        return [
            "valid": report.valid,
            "errorCount": report.errorCount,
            "warningCount": report.warningCount,
            "safeHoldRequired": report.safeHoldRequired,
            "safeHoldReasons": report.safeHoldReasons,
            "errors": errors,
            "warnings": warnings,
        ]
    }
}
