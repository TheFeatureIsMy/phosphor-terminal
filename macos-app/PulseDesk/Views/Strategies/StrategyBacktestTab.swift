// StrategyBacktestTab.swift — 策略内嵌回测标签

import SwiftUI

struct StrategyBacktestTab: View {
    let strategy: Strategy
    let client: NetworkClientProtocol
    @State private var viewModel: BacktestViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: PulseSpacing.lg) {
                        BacktestConfigView(viewModel: vm, strategies: [strategy])

                        if let result = vm.result {
                            BacktestResultsView(backtest: result)
                        }
                    }
                    .padding(PulseSpacing.lg)
                }
                .scrollEdgeEffectStyle(.soft, for: .vertical)
            } else {
                ProgressView()
                    .onAppear {
                        let vm = BacktestViewModel(client: client)
                        vm.selectedStrategyId = strategy.id
                        viewModel = vm
                    }
            }
        }
    }
}
