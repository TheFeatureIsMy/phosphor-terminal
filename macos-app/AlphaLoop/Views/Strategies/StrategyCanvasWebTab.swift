// StrategyCanvasWebTab.swift — Canvas tab using embedded WKWebView + React Flow

import SwiftUI

struct StrategyCanvasWebTab: View {
    @Environment(PulseColors.self) private var colors
    let viewModel: StrategyDetailViewModel
    let client: NetworkClientProtocol

    @State private var canvasVM: CanvasWebViewModel?

    var body: some View {
        Group {
            if let vm = canvasVM {
                ZStack(alignment: .top) {
                    CanvasWebView(viewModel: vm)

                    // Top status overlay
                    HStack(spacing: PulseSpacing.sm) {
                        Spacer()
                        if vm.isSaving {
                            HStack(spacing: 4) {
                                ProgressView().controlSize(.small)
                                Text("保存中...").font(PulseFonts.caption).foregroundStyle(colors.textSecondary)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 6).fill(colors.surfaceElevated))
                        }
                        if vm.saveSuccess {
                            Text("✓ 已保存")
                                .font(PulseFonts.caption).foregroundStyle(PulseColors.accent)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 6).fill(PulseColors.accent.opacity(0.1)))
                        }
                        if let error = vm.error {
                            Text(error)
                                .font(PulseFonts.caption).foregroundStyle(PulseColors.danger)
                                .lineLimit(1)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 6).fill(PulseColors.danger.opacity(0.1)))
                        }
                    }
                    .padding(.horizontal, PulseSpacing.md)
                    .padding(.top, PulseSpacing.xs)

                    // Version load menu
                    if !viewModel.versions.isEmpty {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Menu {
                                    ForEach(viewModel.versions, id: \.id) { version in
                                        Button("v\(version.versionNo) — \(version.status)") {
                                            loadVersion(version, into: vm)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock.arrow.circlepath")
                                        Text("加载版本")
                                    }
                                    .font(PulseFonts.caption)
                                    .foregroundStyle(colors.textSecondary)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(colors.surfaceElevated))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(colors.border, lineWidth: 1))
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                            }
                            .padding(.trailing, PulseSpacing.md)
                            .padding(.bottom, 32)
                        }
                    }
                }
            } else {
                VStack(spacing: PulseSpacing.md) {
                    ProgressView().controlSize(.regular)
                    Text("加载画布...")
                        .font(PulseFonts.body).foregroundStyle(colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            let vm = CanvasWebViewModel(strategyId: viewModel.strategyId, client: client)
            vm.errorHandler = viewModel.errorHandler
            canvasVM = vm

            // Load latest version DSL into canvas
            if let latest = viewModel.versions.first {
                let dsl = encodableToDict(latest.ruleDsl)
                vm.loadDSL(dsl)
            }
        }
    }

    private func loadVersion(_ version: StrategyVersionV2, into vm: CanvasWebViewModel) {
        let dsl = encodableToDict(version.ruleDsl)
        vm.loadDSL(dsl)
    }

    private func encodableToDict(_ dict: [String: AnyCodable]) -> [String: Any] {
        dict.mapValues { $0.value }
    }
}
