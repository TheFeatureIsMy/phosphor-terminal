import SwiftUI

enum CreateMode { case manual, aiChat }

struct StrategyCreatePanel: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    @Environment(\.networkClient) private var networkClient

    @State private var mode: CreateMode = .manual
    @State private var name = ""
    @State private var selectedMarket: MarketType = .crypto
    @State private var selectedExchange: Exchange = .binance
    @State private var isCreating = false

    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            modeSwitcher
                .padding(.horizontal, PulseSpacing.lg)
                .padding(.top, PulseSpacing.md)

            Divider().foregroundStyle(colors.border).padding(.top, PulseSpacing.sm)

            if mode == .manual {
                manualForm
            } else {
                AIChatView { strategyId in
                    appState.selectedStrategyId = strategyId
                    appState.selectedRoute = .strategyDetail
                }
            }
        }
        .padding(.bottom, PulseSpacing.md)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.lg))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.lg).stroke(colors.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 12)
    }

    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            ForEach([("手动创建", CreateMode.manual), ("AI 对话创建", CreateMode.aiChat)], id: \.0) { label, m in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { mode = m }
                } label: {
                    Text(label)
                        .font(.system(size: 11, weight: mode == m ? .semibold : .regular))
                        .foregroundStyle(mode == m ? PulseColors.accent : colors.textMuted)
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(mode == m ? colors.surfaceElevated : .clear)
                        )
                        .shadow(color: mode == m ? .black.opacity(0.15) : .clear, radius: 2, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var manualForm: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("策略名称").font(PulseFonts.captionMedium).foregroundStyle(colors.textMuted)
                TextField("输入策略名称...", text: $name)
                    .textFieldStyle(.plain).font(PulseFonts.body)
                    .foregroundStyle(colors.textPrimary)
                    .padding(10).background(colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                    .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(
                        !name.isEmpty ? PulseColors.accent.opacity(0.3) : colors.border, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("交易市场").font(PulseFonts.captionMedium).foregroundStyle(colors.textMuted)
                pillSelector(MarketType.allCases.map { ($0.label, $0) }, selected: selectedMarket) { selectedMarket = $0 }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("交易所").font(PulseFonts.captionMedium).foregroundStyle(colors.textMuted)
                pillSelector(availableExchanges, selected: selectedExchange) { selectedExchange = $0 }
            }

            HStack(spacing: 4) {
                Image(systemName: "lightbulb").font(.system(size: 9)).foregroundStyle(PulseColors.amber)
                Text("创建后进入画布，从调色板拖入节点开始构建策略逻辑")
                    .font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            }
            .padding(8).background(colors.background)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))

            HStack {
                ProofAlphaButton(title: "取消", action: onCancel, style: .ghost)
                Spacer()
                ProofAlphaButton(title: "创建并打开画布 →") { Task { await doCreate() } }
                    .opacity(name.isEmpty ? 0.5 : 1).disabled(name.isEmpty)
            }
            .padding(.top, PulseSpacing.sm)
        }
        .padding(PulseSpacing.lg)
    }

    private func pillSelector<T: Identifiable & Hashable>(_ items: [(String, T)], selected: T, onSelect: @escaping (T) -> Void) -> some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.0) { label, item in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { onSelect(item) }
                } label: {
                    Text(label)
                        .font(.system(size: 10, weight: selected.hashValue == item.hashValue ? .semibold : .regular))
                        .foregroundStyle(selected.hashValue == item.hashValue ? colors.background : colors.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selected.hashValue == item.hashValue ? PulseColors.accent : colors.background)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selected.hashValue == item.hashValue ? .clear : colors.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var availableExchanges: [(String, Exchange)] {
        switch selectedMarket {
        case .crypto: return [("Binance", .binance), ("OKX", .okx), ("Bybit", .bybit), ("Gate", .gate)]
        case .usStock: return [("Alpaca", .alpaca), ("IBKR", .ibkr)]
        case .aShare: return [("JoinQuant", .joinquant), ("EastMoney", .eastmoney)]
        }
    }

    private func doCreate() async {
        isCreating = true
        let api = APIStrategies(client: networkClient)
        if let strategy = try? await api.create(name: name, type: .maCross, market: selectedMarket.rawValue, exchange: selectedExchange.rawValue) {
            appState.selectedStrategyId = strategy.id
            appState.selectedRoute = .strategyDetail
        }
        isCreating = false
    }
}
