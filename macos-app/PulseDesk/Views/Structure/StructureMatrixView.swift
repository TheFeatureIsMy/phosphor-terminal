// StructureMatrixView.swift — 结构矩阵 (Redesigned)

import SwiftUI

struct StructureMatrixView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var viewModel: StructureMatrixViewModel?

    private let symbols = ["BTC/USDT", "ETH/USDT"]

    var body: some View {
        VStack(spacing: 0) {
            if let vm = viewModel {
                if vm.isLoading && vm.matrixData == nil {
                    LoadingView(type: .grid)
                        .padding(PulseSpacing.lg)
                } else if let data = vm.matrixData {
                    // Header
                    headerSection(vm)

                    Divider().foregroundStyle(colors.border)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: PulseSpacing.lg) {
                            // State banner
                            stateBanner(data)

                            // Matrix grid
                            matrixGrid(data)

                            // Shadow window panel
                            shadowWindowPanel(data)
                        }
                        .padding(PulseSpacing.lg)
                    }
                    .scrollEdgeEffectStyle(.soft, for: .vertical)
                } else if let error = vm.error {
                    EmptyStateView(
                        icon: "exclamationmark.triangle",
                        title: L10n.Common.error,
                        description: error,
                        primaryAction: (title: L10n.Common.retry, action: { Task { await vm.loadMatrix() } })
                    )
                    .padding(PulseSpacing.lg)
                } else {
                    EmptyStateView(
                        icon: "square.grid.3x3",
                        title: L10n.Common.noData,
                        description: ""
                    )
                    .padding(PulseSpacing.lg)
                }
            }
        }
        .task {
            let vm = StructureMatrixViewModel(client: networkClient)
            viewModel = vm
            await vm.loadMatrix()
        }
    }

    // MARK: - Header

    private func headerSection(_ vm: StructureMatrixViewModel) -> some View {
        HStack {
            Text(L10n.Structure.matrix)
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textPrimary)

            Picker("Symbol", selection: Binding(
                get: { vm.selectedSymbol },
                set: { newValue in
                    vm.selectedSymbol = newValue
                    Task { await vm.loadMatrix() }
                }
            )) {
                ForEach(symbols, id: \.self) { symbol in
                    Text(symbol).tag(symbol)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Spacer()

            Button {
                Task { await vm.refresh() }
            } label: {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                    Text(L10n.Common.refresh)
                        .font(PulseFonts.monoLabel)
                }
                .foregroundStyle(PulseColors.accent)
            }
            .buttonStyle(.plain)
            .controlSize(.small)
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.md)
    }

    // MARK: - State Banner

    @ViewBuilder
    private func stateBanner(_ data: StructureMatrixBFFResponse) -> some View {
        if data.state != "healthy" {
            HStack(spacing: PulseSpacing.sm) {
                Image(systemName: data.state == "violated" ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(data.state == "violated" ? PulseColors.StateColors.red : PulseColors.StateColors.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(data.state == "violated" ? L10n.Structure.stateViolated : L10n.Structure.stateWarning)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)

                    if !data.reasonCodes.isEmpty {
                        Text(data.reasonCodes.joined(separator: ", "))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }
                }

                Spacer()
            }
            .padding(PulseSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill((data.state == "violated" ? PulseColors.StateColors.red : PulseColors.StateColors.orange).opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke((data.state == "violated" ? PulseColors.StateColors.red : PulseColors.StateColors.orange).opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Matrix Grid

    private func matrixGrid(_ data: StructureMatrixBFFResponse) -> some View {
        let allZoneKeys = extractZoneKeys(from: data.rows)

        return VStack(spacing: PulseSpacing.xs) {
            // Header row with TermText for zone keys
            HStack(spacing: PulseSpacing.xs) {
                Text(L10n.Structure.timeframe)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .frame(width: 40)
                ForEach(allZoneKeys, id: \.self) { zone in
                    TermText(term: formatZoneKey(zone), fontSize: 9)
                        .frame(maxWidth: .infinity)
                }
            }

            // Data rows
            ForEach(Array(data.rows.enumerated()), id: \.element.timeframe) { index, row in
                matrixRow(row: row, zoneKeys: allZoneKeys)
                    .staggeredAppearance(index: index)
            }
        }
    }

    /// Format zone key for display (e.g. "bullish_ob" -> "OB")
    private func formatZoneKey(_ key: String) -> String {
        if key.contains("ob") { return "OB" }
        if key.contains("fvg") { return "FVG" }
        if key.contains("choch") { return "CHoCH" }
        if key.contains("bos") { return "BOS" }
        return key.uppercased()
    }

    /// Extract all unique zone keys across all rows, preserving order of first appearance.
    private func extractZoneKeys(from rows: [MatrixRowResponse]) -> [String] {
        var seen = Set<String>()
        var keys: [String] = []
        for row in rows {
            for key in row.cells.keys.sorted() {
                if seen.insert(key).inserted {
                    keys.append(key)
                }
            }
        }
        return keys
    }

    private func matrixRow(row: MatrixRowResponse, zoneKeys: [String]) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            Text(row.timeframe)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textPrimary)
                .frame(width: 40)

            ForEach(zoneKeys, id: \.self) { zoneKey in
                if let cell = row.cells[zoneKey] {
                    MatrixCellView(cell: cell, timeframe: row.timeframe, zoneKey: zoneKey)
                } else {
                    // Empty placeholder for missing cell
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colors.surface.opacity(0.3))
                        .frame(height: 36)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            Text("—")
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                        }
                }
            }
        }
    }

    // MARK: - Shadow Window Panel

    private func shadowWindowPanel(_ data: StructureMatrixBFFResponse) -> some View {
        // Collect cells with temporaryViolation or warning/violated status
        let shadowEntries = collectShadowEntries(from: data.rows)

        return Group {
            if !shadowEntries.isEmpty {
                VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                    TerminalLabel(text: L10n.Structure.shadowWindow)

                    HStack(spacing: PulseSpacing.md) {
                        ForEach(Array(shadowEntries.enumerated()), id: \.offset) { _, entry in
                            shadowItem(
                                tf: entry.timeframe,
                                zoneKey: entry.zoneKey,
                                cell: entry.cell
                            )
                        }
                    }
                }
            }
        }
    }

    private struct ShadowEntry {
        let timeframe: String
        let zoneKey: String
        let cell: MatrixCellResponse
    }

    private func collectShadowEntries(from rows: [MatrixRowResponse]) -> [ShadowEntry] {
        var entries: [ShadowEntry] = []
        for row in rows {
            for (key, cell) in row.cells {
                if cell.temporaryViolation || cell.status == "warning" || cell.status == "violated" {
                    entries.append(ShadowEntry(timeframe: row.timeframe, zoneKey: key, cell: cell))
                }
            }
        }
        return entries
    }

    private func shadowItem(tf: String, zoneKey: String, cell: MatrixCellResponse) -> some View {
        let color = cellColor(cell.status)

        return VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
            HStack(spacing: PulseSpacing.xxs) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text("\(tf) ")
                    .font(PulseFonts.bodyMedium)
                    .foregroundStyle(colors.textPrimary)
                TermText(term: formatZoneKey(zoneKey), fontSize: 11)
            }

            if cell.temporaryViolation {
                Text(L10n.Structure.violation)
                    .font(PulseFonts.micro)
                    .foregroundStyle(PulseColors.StateColors.yellow)
            }

            if !cell.reasonCodes.isEmpty {
                ForEach(cell.reasonCodes, id: \.self) { code in
                    Text(code)
                        .font(PulseFonts.micro)
                        .foregroundStyle(color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(color.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(PulseSpacing.sm)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    // MARK: - Helpers

    private func cellColor(_ status: String) -> Color {
        switch status {
        case "active": return PulseColors.StateColors.green
        case "warning": return PulseColors.StateColors.yellow
        case "violated": return PulseColors.StateColors.red
        default: return PulseColors.StateColors.gray
        }
    }
}

// MARK: - Matrix Cell View (extracted for popover + animation support)

private struct MatrixCellView: View {
    let cell: MatrixCellResponse
    let timeframe: String
    let zoneKey: String
    @Environment(PulseColors.self) private var colors
    @State private var showPopover = false
    @State private var pulseOpacity: Double = 0.0

    var body: some View {
        let color = cellColor

        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.10 + cell.currentStrength * 0.2),
                            color.opacity(0.15 + cell.currentStrength * 0.4),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 36)
                .overlay {
                    VStack(spacing: 1) {
                        Text("\(Int(cell.currentStrength * 100))%")
                            .font(PulseFonts.captionMedium)
                            .foregroundStyle(color)
                        if cell.action != "allow" && !cell.action.isEmpty {
                            Text(actionLabel)
                                .font(PulseFonts.micro)
                                .foregroundStyle(PulseColors.StateColors.yellow)
                        }
                    }
                }
                .overlay(
                    // Pulse animation for temporaryViolation
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(PulseColors.StateColors.yellow.opacity(pulseOpacity), lineWidth: 1.5)
                        .opacity(cell.temporaryViolation ? 1 : 0)
                )

            if cell.temporaryViolation {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(PulseColors.StateColors.yellow)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { showPopover = true }
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            cellDetailPopover
        }
        .onAppear {
            if cell.temporaryViolation {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.8
                }
            }
        }
    }

    private var actionLabel: String {
        switch cell.action {
        case "reduce_size": return L10n.Structure.reduce
        case "block": return L10n.Structure.block
        case "allow": return L10n.Structure.allow
        default: return cell.action
        }
    }

    private var cellColor: Color {
        switch cell.status {
        case "active": return PulseColors.StateColors.green
        case "warning": return PulseColors.StateColors.yellow
        case "violated": return PulseColors.StateColors.red
        default: return PulseColors.StateColors.gray
        }
    }

    @ViewBuilder
    private var cellDetailPopover: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack {
                Text("\(timeframe)")
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(colors.textPrimary)
                TermText(term: zoneKey.contains("ob") ? "OB" : "FVG", fontSize: 11)
                Spacer()
            }

            Divider().opacity(0.3)

            LabeledContent(L10n.Structure.strength) {
                Text(String(format: "%.0f%%", cell.currentStrength * 100))
                    .font(PulseFonts.tabular)
            }
            .font(PulseFonts.caption)
            .foregroundStyle(colors.textSecondary)

            LabeledContent(L10n.Common.status) {
                Text(statusLabel)
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(cellColor)
            }
            .font(PulseFonts.caption)
            .foregroundStyle(colors.textSecondary)

            LabeledContent(L10n.Structure.action) {
                Text(actionLabel)
                    .font(PulseFonts.captionMedium)
            }
            .font(PulseFonts.caption)
            .foregroundStyle(colors.textSecondary)

            if cell.temporaryViolation {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(PulseColors.StateColors.yellow)
                    Text(L10n.Structure.violation)
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.StateColors.yellow)
                }
            }

            if !cell.reasonCodes.isEmpty {
                Divider().opacity(0.3)
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    ForEach(cell.reasonCodes, id: \.self) { code in
                        Text(code)
                            .font(PulseFonts.micro)
                            .foregroundStyle(cellColor)
                            .padding(.horizontal, PulseSpacing.xxs)
                            .padding(.vertical, 1)
                            .background(cellColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(PulseSpacing.md)
        .frame(width: 240)
    }

    private var statusLabel: String {
        switch cell.status {
        case "active": return L10n.Structure.stateHealthy
        case "warning": return L10n.Structure.stateWarning
        case "violated": return L10n.Structure.stateViolated
        default: return cell.status
        }
    }
}
