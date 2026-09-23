// AddProviderSheet.swift — 新增服务/Provider

import SwiftUI

struct AddProviderSheet: View {
    @Bindable var vm: ServiceManagementViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(PulseColors.self) private var colors

    private let categories = ["llm", "cex", "dex", "market_data", "onchain", "social", "news", "notification"]

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            HStack {
                Text(L10n.zh("新增服务", en: "Add Provider"))
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

                PulseTextField(label: L10n.zh("供应商", en: "Provider"), text: $vm.newProviderName,
                    placeholder: L10n.zh("如 anthropic, binance", en: "e.g. anthropic, binance"))

                PulseTextField(label: L10n.zh("实例名称", en: "Instance"), text: $vm.newInstanceName,
                    placeholder: L10n.zh("可选", en: "Optional"))

                PulseSecureField(label: "API Key", text: $vm.newApiKey,
                    placeholder: L10n.zh("输入 API Key", en: "Enter API Key"))
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
        .frame(width: 460, height: 400)
        .background(colors.background)
    }
}
