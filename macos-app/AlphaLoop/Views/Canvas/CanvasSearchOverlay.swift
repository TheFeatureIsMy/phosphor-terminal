// CanvasSearchOverlay.swift — 画布搜索覆盖层

import SwiftUI

struct CanvasSearchOverlay: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @Binding var isPresented: Bool
    @Binding var searchText: String
    let matchCount: Int
    let currentMatchIndex: Int
    let onNavigate: (Bool) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(colors.textMuted)

                TextField(L10n.zh("搜索节点...", en: "Search nodes..."), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textPrimary)
                    .focused($isFocused)

                if !searchText.isEmpty {
                    Text("\(currentMatchIndex + 1)/\(matchCount)")
                        .font(PulseFonts.micro)
                        .foregroundStyle(matchCount > 0 ? colors.textSecondary : PulseColors.danger)
                        .monospacedDigit()

                    Button { onNavigate(false) } label: {
                        Image(systemName: "chevron.up").font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(matchCount == 0)

                    Button { onNavigate(true) } label: {
                        Image(systemName: "chevron.down").font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(matchCount == 0)
                }

                Button { isPresented = false; searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(colors.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
        .id(settingsState.language)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colors.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(colors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 12)
        .onAppear { isFocused = true }
    }
}
