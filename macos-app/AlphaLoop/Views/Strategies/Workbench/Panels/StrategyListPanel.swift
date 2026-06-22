// StrategyListPanel.swift — ⌘1 strategy list / search / filter / new-draft
// (Plan 2026-06-18 Task 19. Migrates the old StrategySwitcherPanel content
// into PanelChrome, drops popover positioning.)
import SwiftUI

struct StrategyListPanel: View {
    @Environment(PulseColors.self) private var colors
    let vm: StrategyWorkspaceViewModel

    var body: some View {
        PanelChrome(
            title: L10n.Workbench.panelList,
            icon: WorkbenchPanel.list.icon,
            onClose: { vm.closePanel() }
        ) {
            VStack(spacing: 0) {
                searchBar
                filterChips
                Divider().overlay(colors.border)
                list
                Divider().overlay(colors.border)
                footer
            }
            .padding(-12) // PanelChrome wraps content with 12pt; we want flush
        }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(colors.textMuted)
            TextField(L10n.Workbench.railSearch, text: Binding(
                get: { vm.search },
                set: { vm.search = $0 }
            ))
            .textFieldStyle(.plain)
            .font(PulseFonts.caption)
            .foregroundStyle(colors.textPrimary)
        }
        .padding(.horizontal, PulseSpacing.sm)
        .padding(.vertical, 8)
    }

    private var filterChips: some View {
        HStack(spacing: 4) {
            ForEach(TrackFilter.allCases) { f in
                chip(f)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PulseSpacing.sm)
        .padding(.bottom, 8)
    }

    private func chip(_ f: TrackFilter) -> some View {
        let active = vm.filter == f
        return Button { vm.filter = f } label: {
            Text(f.label)
                .font(PulseFonts.micro)
                .tracking(0.8)
                .foregroundStyle(active ? .black : colors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(active ? PulseColors.accent : colors.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(vm.filteredStrategies) { s in
                    row(s)
                }
                if vm.filteredStrategies.isEmpty && !vm.isLoadingList {
                    Text(L10n.Strategies.empty)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                        .padding(.top, 32)
                }
            }
            .padding(6)
        }
        .frame(maxHeight: 360)
    }

    private func row(_ s: StrategyV2) -> some View {
        let selected = vm.selectedStrategyId == s.id
        let stage = LifecycleStage.from(status: s.status)
        let color: Color = {
            switch stage {
            case .draft: return colors.textMuted
            case .validated, .backtested: return PulseColors.cyan
            case .paperRun, .paperPass, .livePending: return PulseColors.amber
            case .liveSmall: return PulseColors.accent
            }
        }()
        return Button {
            Task { await vm.select(strategyId: s.id) }
        } label: {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.name)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(selected ? colors.textPrimary : colors.textSecondary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(s.strategyType.uppercased())
                            .font(PulseFonts.micro)
                            .tracking(0.6)
                            .foregroundStyle(colors.textMuted)
                        Text("·").foregroundStyle(colors.textMuted).font(PulseFonts.micro)
                        Text(stage.label)
                            .font(PulseFonts.micro)
                            .foregroundStyle(color)
                    }
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PulseColors.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(selected ? colors.surfaceElevated : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        Button {
            Task {
                let name = L10n.zh("未命名草稿", en: "Untitled Draft")
                _ = await vm.createDraft(name: name)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill").font(.system(size: 11, weight: .semibold))
                Text(L10n.Workbench.newDraft).font(PulseFonts.captionMedium)
                Spacer()
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                LinearGradient(
                    colors: [PulseColors.accent, PulseColors.accentLight],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        }
        .buttonStyle(.plain)
        .padding(8)
    }
}
