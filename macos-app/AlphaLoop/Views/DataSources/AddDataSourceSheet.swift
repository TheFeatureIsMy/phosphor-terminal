// AddDataSourceSheet.swift — 新增数据源

import SwiftUI

struct AddDataSourceSheet: View {
    @Bindable var vm: DataSourcesViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(PulseColors.self) private var colors

    private let categories = ["market_data", "cex", "dex", "onchain", "social", "news", "llm", "notification"]

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            HStack {
                Text(L10n.zh("新增数据源", en: "Add Data Source"))
                    .font(PulseFonts.displaySubheading)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .medium))
                        .foregroundStyle(colors.textMuted).padding(6)
                        .background(colors.surface).clipShape(Circle())
                }.buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                PulseDropdown(label: L10n.zh("类别", en: "Category"), selection: $vm.newCategory,
                    options: categories.map { ($0, $0.replacingOccurrences(of: "_", with: " ").capitalized) })

                PulseTextField(label: L10n.zh("供应商名称", en: "Provider Name"), text: $vm.newProviderName,
                    placeholder: L10n.zh("如 binance, coingecko", en: "e.g. binance, coingecko"))

                PulseTextField(label: L10n.zh("实例名称", en: "Instance Name"), text: $vm.newInstanceName,
                    placeholder: L10n.zh("可选，区分多实例", en: "Optional"))

                PulseSecureField(label: "API Key", text: $vm.newApiKey,
                    placeholder: L10n.zh("输入 API Key", en: "Enter API Key"))

                PulseSecureField(label: "API Secret", text: $vm.newApiSecret,
                    placeholder: L10n.zh("可选", en: "Optional"))
            }

            Spacer()

            HStack {
                PulseActionButton(label: L10n.zh("取消", en: "Cancel"), style: .secondary) { dismiss() }
                Spacer()
                PulseActionButton(label: L10n.zh("创建", en: "Create"), icon: "plus",
                    style: .primary, isLoading: vm.isCreating,
                    isDisabled: vm.newProviderName.isEmpty) { Task { await vm.createProvider() } }
            }
        }
        .padding(PulseSpacing.xl)
        .frame(width: 480, height: 440)
        .background(colors.background)
    }
}
