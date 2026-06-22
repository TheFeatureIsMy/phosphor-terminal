// NodeConfigForms.swift — 9 native SwiftUI forms for ⌘2 NodeConfigPanel
// Plan 2026-06-18 Task 20. Each form mirrors the data shape of the matching
// canvas-web/src/nodes/<Type>Node.tsx so updates round-trip via
// CanvasWebViewModel.updateNodeData(nodeId:data:).

import SwiftUI

// MARK: - Helpers

private struct FormSection<Content: View>: View {
    @Environment(PulseColors.self) private var colors
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(PulseFonts.micro)
                .tracking(0.6)
                .foregroundStyle(colors.textMuted)
            content()
        }
    }
}

private func numberBinding(_ value: Binding<Double>) -> Binding<String> {
    Binding(
        get: { String(format: "%g", value.wrappedValue) },
        set: { value.wrappedValue = Double($0) ?? value.wrappedValue }
    )
}

private func intBinding(_ value: Binding<Int>) -> Binding<String> {
    Binding(
        get: { String(value.wrappedValue) },
        set: { value.wrappedValue = Int($0) ?? value.wrappedValue }
    )
}

// MARK: - Signal Input

struct SignalInputForm: View {
    let initial: [String: Any]
    let onCommit: ([String: Any]) -> Void

    @State private var symbols: String = ""
    @State private var timeframe: String = "1h"
    @State private var source: String = "signal_center"

    private let timeframes = ["1m", "5m", "15m", "30m", "1h", "4h", "1d"]
    private let sources = ["signal_center", "manual"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormSection(label: L10n.Workbench.nodeFieldSymbols) {
                TextField("BTC/USDT,ETH/USDT", text: $symbols)
                    .textFieldStyle(.roundedBorder)
            }
            FormSection(label: L10n.Workbench.nodeFieldTimeframe) {
                Picker("", selection: $timeframe) {
                    ForEach(timeframes, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            FormSection(label: L10n.Workbench.nodeFieldSource) {
                Picker("", selection: $source) {
                    ForEach(sources, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            commitButton
        }
        .onAppear {
            if let arr = initial["symbols"] as? [String] { symbols = arr.joined(separator: ",") }
            if let s = initial["timeframe"] as? String { timeframe = s }
            if let s = initial["source"] as? String { source = s }
        }
    }

    private var commitButton: some View {
        Button(L10n.zh("应用", en: "Apply")) {
            let syms = symbols.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            var d = initial
            d["symbols"] = syms
            d["timeframe"] = timeframe
            d["source"] = source
            onCommit(d)
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - Indicator Condition

struct IndicatorConditionForm: View {
    let initial: [String: Any]
    let onCommit: ([String: Any]) -> Void

    @State private var indicator: String = "rsi"
    @State private var op: String = ">"
    @State private var value: Double = 70
    @State private var period: Int = 14

    private let indicators = ["rsi", "macd", "ema", "sma", "atr", "bollinger"]
    private let operators = [">", "<", ">=", "<=", "==", "!="]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormSection(label: L10n.Workbench.nodeFieldIndicator) {
                Picker("", selection: $indicator) {
                    ForEach(indicators, id: \.self) { Text($0.uppercased()).tag($0) }
                }
                .labelsHidden().pickerStyle(.menu)
            }
            FormSection(label: L10n.Workbench.nodeFieldOperator) {
                Picker("", selection: $op) {
                    ForEach(operators, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden().pickerStyle(.segmented)
            }
            FormSection(label: L10n.Workbench.nodeFieldValue) {
                TextField("0", text: numberBinding($value))
                    .textFieldStyle(.roundedBorder)
            }
            FormSection(label: L10n.Workbench.nodeFieldTimeframe) {
                TextField("14", text: intBinding($period))
                    .textFieldStyle(.roundedBorder)
            }
            commitButton
        }
        .onAppear {
            if let s = initial["indicator"] as? String { indicator = s }
            if let s = initial["operator"] as? String { op = s }
            if let v = initial["value"] as? Double { value = v }
            else if let v = initial["value"] as? Int { value = Double(v) }
            if let p = (initial["params"] as? [String: Any])?["period"] as? Int { period = p }
        }
    }

    private var commitButton: some View {
        Button(L10n.zh("应用", en: "Apply")) {
            var d = initial
            d["indicator"] = indicator
            d["operator"] = op
            d["value"] = value
            d["params"] = ["period": period]
            onCommit(d)
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - Filter

struct FilterForm: View {
    let initial: [String: Any]
    let onCommit: ([String: Any]) -> Void

    @State private var ruleType: String = "volume_filter"
    @State private var op: String = ">"
    @State private var value: Double = 1.0
    @State private var candles: Int = 5

    private let ruleTypes = ["volume_filter", "atr_filter", "trend_filter", "cooldown_filter"]
    private let operators = [">", "<", ">=", "<="]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormSection(label: L10n.Workbench.nodeFieldRuleType) {
                Picker("", selection: $ruleType) {
                    ForEach(ruleTypes, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden().pickerStyle(.menu)
            }
            FormSection(label: L10n.Workbench.nodeFieldOperator) {
                Picker("", selection: $op) {
                    ForEach(operators, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden().pickerStyle(.segmented)
            }
            FormSection(label: L10n.Workbench.nodeFieldValue) {
                TextField("1.0", text: numberBinding($value))
                    .textFieldStyle(.roundedBorder)
            }
            FormSection(label: L10n.Workbench.nodeFieldCandles) {
                TextField("5", text: intBinding($candles))
                    .textFieldStyle(.roundedBorder)
            }
            commitButton
        }
        .onAppear {
            if let s = initial["ruleType"] as? String { ruleType = s }
            if let s = initial["operator"] as? String { op = s }
            if let v = initial["value"] as? Double { value = v }
            else if let v = initial["value"] as? Int { value = Double(v) }
            if let c = initial["candles"] as? Int { candles = c }
        }
    }

    private var commitButton: some View {
        Button(L10n.zh("应用", en: "Apply")) {
            var d = initial
            d["ruleType"] = ruleType
            d["operator"] = op
            d["value"] = value
            d["candles"] = candles
            onCommit(d)
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - Position Sizing

struct PositionSizingForm: View {
    let initial: [String: Any]
    let onCommit: ([String: Any]) -> Void

    @State private var positionPct: Double = 0.1

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormSection(label: L10n.Workbench.nodeFieldPositionPct) {
                HStack {
                    Slider(value: $positionPct, in: 0.01...1.0, step: 0.01)
                    Text("\(Int(positionPct * 100))%")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }
            commitButton
        }
        .onAppear {
            if let v = initial["positionPct"] as? Double { positionPct = v }
        }
    }

    private var commitButton: some View {
        Button(L10n.zh("应用", en: "Apply")) {
            var d = initial
            d["positionPct"] = positionPct
            onCommit(d)
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - Risk Policy

struct RiskPolicyForm: View {
    let initial: [String: Any]
    let onCommit: ([String: Any]) -> Void

    @State private var stoploss: Double = 0.05
    @State private var maxOpen: Int = 3
    @State private var trailing: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormSection(label: L10n.Workbench.nodeFieldStoploss) {
                HStack {
                    Slider(value: $stoploss, in: 0.01...0.30, step: 0.005)
                    Text("\(String(format: "%.1f", stoploss * 100))%")
                        .monospacedDigit().frame(width: 48, alignment: .trailing)
                }
            }
            FormSection(label: L10n.Workbench.nodeFieldMaxOpen) {
                TextField("3", text: intBinding($maxOpen))
                    .textFieldStyle(.roundedBorder)
            }
            Toggle(L10n.Workbench.nodeFieldTrailing, isOn: $trailing)
            commitButton
        }
        .onAppear {
            if let v = initial["stoploss"] as? Double { stoploss = v }
            if let v = initial["maxOpenTrades"] as? Int { maxOpen = v }
            if let v = initial["trailingStop"] as? Bool { trailing = v }
        }
    }

    private var commitButton: some View {
        Button(L10n.zh("应用", en: "Apply")) {
            var d = initial
            d["stoploss"] = stoploss
            d["maxOpenTrades"] = maxOpen
            d["trailingStop"] = trailing
            onCommit(d)
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - Execution Output

struct ExecutionOutputForm: View {
    let initial: [String: Any]
    let onCommit: ([String: Any]) -> Void

    @State private var entry: String = "all"
    @State private var exit: String = "all"

    private let logics = ["all", "any", "majority"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormSection(label: L10n.Workbench.nodeFieldEntry) {
                Picker("", selection: $entry) {
                    ForEach(logics, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden().pickerStyle(.segmented)
            }
            FormSection(label: L10n.Workbench.nodeFieldExit) {
                Picker("", selection: $exit) {
                    ForEach(logics, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden().pickerStyle(.segmented)
            }
            commitButton
        }
        .onAppear {
            if let s = initial["entryLogic"] as? String { entry = s }
            if let s = initial["exitLogic"] as? String { exit = s }
        }
    }

    private var commitButton: some View {
        Button(L10n.zh("应用", en: "Apply")) {
            var d = initial
            d["entryLogic"] = entry
            d["exitLogic"] = exit
            onCommit(d)
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - Structure Defense

struct StructureDefenseForm: View {
    let initial: [String: Any]
    let onCommit: ([String: Any]) -> Void

    @State private var structures: String = "liquidity_pool,fvg"
    @State private var minScore: Int = 70

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormSection(label: L10n.Workbench.nodeFieldStructures) {
                TextField("liquidity_pool,fvg", text: $structures)
                    .textFieldStyle(.roundedBorder)
            }
            FormSection(label: L10n.Workbench.nodeFieldMinScore) {
                TextField("70", text: intBinding($minScore))
                    .textFieldStyle(.roundedBorder)
            }
            commitButton
        }
        .onAppear {
            if let arr = initial["structures"] as? [String] { structures = arr.joined(separator: ",") }
            if let v = initial["minStructureScore"] as? Int { minScore = v }
        }
    }

    private var commitButton: some View {
        Button(L10n.zh("应用", en: "Apply")) {
            let arr = structures.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            var d = initial
            d["structures"] = arr
            d["minStructureScore"] = minScore
            onCommit(d)
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - Account Risk

struct AccountRiskForm: View {
    let initial: [String: Any]
    let onCommit: ([String: Any]) -> Void

    @State private var daily: Double = 0.03
    @State private var weekly: Double = 0.08
    @State private var consec: Int = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormSection(label: L10n.Workbench.nodeFieldDailyLoss) {
                HStack {
                    Slider(value: $daily, in: 0.005...0.15, step: 0.005)
                    Text("\(String(format: "%.1f", daily * 100))%").monospacedDigit().frame(width: 48, alignment: .trailing)
                }
            }
            FormSection(label: L10n.Workbench.nodeFieldWeeklyLoss) {
                HStack {
                    Slider(value: $weekly, in: 0.01...0.30, step: 0.005)
                    Text("\(String(format: "%.1f", weekly * 100))%").monospacedDigit().frame(width: 48, alignment: .trailing)
                }
            }
            FormSection(label: L10n.Workbench.nodeFieldConsecLoss) {
                TextField("4", text: intBinding($consec))
                    .textFieldStyle(.roundedBorder)
            }
            commitButton
        }
        .onAppear {
            if let v = initial["maxDailyLoss"] as? Double { daily = v }
            if let v = initial["maxWeeklyLoss"] as? Double { weekly = v }
            if let v = initial["maxConsecutiveLosses"] as? Int { consec = v }
        }
    }

    private var commitButton: some View {
        Button(L10n.zh("应用", en: "Apply")) {
            var d = initial
            d["maxDailyLoss"] = daily
            d["maxWeeklyLoss"] = weekly
            d["maxConsecutiveLosses"] = consec
            onCommit(d)
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - MTF Guard

struct MTFGuardForm: View {
    let initial: [String: Any]
    let onCommit: ([String: Any]) -> Void

    @State private var fastTf: String = "5m"
    @State private var slowTf: String = "1h"
    @State private var structureType: String = "order_block"

    private let timeframes = ["1m", "5m", "15m", "30m", "1h", "4h", "1d"]
    private let structureTypes = ["order_block", "fair_value_gap", "liquidity_pool", "support_resistance"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormSection(label: L10n.Workbench.nodeFieldFastTf) {
                Picker("", selection: $fastTf) {
                    ForEach(timeframes, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden().pickerStyle(.menu)
            }
            FormSection(label: L10n.Workbench.nodeFieldSlowTf) {
                Picker("", selection: $slowTf) {
                    ForEach(timeframes, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden().pickerStyle(.menu)
            }
            FormSection(label: L10n.Workbench.nodeFieldStructureType) {
                Picker("", selection: $structureType) {
                    ForEach(structureTypes, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ")).tag($0) }
                }
                .labelsHidden().pickerStyle(.menu)
            }
            commitButton
        }
        .onAppear {
            if let s = initial["fastTimeframe"] as? String { fastTf = s }
            if let s = initial["slowTimeframe"] as? String { slowTf = s }
            if let s = initial["structureType"] as? String { structureType = s }
        }
    }

    private var commitButton: some View {
        Button(L10n.zh("应用", en: "Apply")) {
            var d = initial
            d["fastTimeframe"] = fastTf
            d["slowTimeframe"] = slowTf
            d["structureType"] = structureType
            onCommit(d)
        }
        .buttonStyle(.borderedProminent)
    }
}
