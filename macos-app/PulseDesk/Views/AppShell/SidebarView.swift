// SidebarView.swift — Krypton Pro 极窄侧边栏 (48dp)
// Phase 2: 3 工作区图标 + 底部 ⌘K / ⚙

import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(spacing: 0) {
            // Logo
            Button {
                appState.selectedRoute = .dashboard
            } label: {
                KryptonLogoView()
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
            .padding(.bottom, 28)

            // 3 Workspace icons
            VStack(spacing: 8) {
                ForEach(PrimaryWorkspace.allCases) { ws in
                    WorkspaceIconButton(workspace: ws)
                }
            }

            Spacer(minLength: 0)

            // Bottom: ⌘K + Settings
            VStack(spacing: 8) {
                Button {
                    appState.showCommandPalette.toggle()
                } label: {
                    Text("\u{2318}")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(colors.textMuted)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.md)
                                .fill(Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help("Command Palette (⌘K)")

                Button {
                    appState.selectedRoute = .systemSettings
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundStyle(colors.textMuted)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.md)
                                .fill(Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help("系统设置")
            }
            .padding(.bottom, 16)
        }
        .frame(width: 48)
        .overlay(alignment: .trailing) {
            Rectangle().fill(colors.border).frame(width: 1)
        }
    }
}

// MARK: - Workspace Icon Button

struct WorkspaceIconButton: View {
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors
    @State private var isHovering = false
    let workspace: PrimaryWorkspace

    private var isActive: Bool { appState.primaryWorkspace == workspace }

    var body: some View {
        Button {
            withAnimation(PulseAnimation.easeOutFast) {
                appState.selectedRoute = workspace.defaultRoute
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: PulseRadii.md)
                    .fill(isActive ? KryptonColor.amber.opacity(0.1) : (isHovering ? colors.surfaceHover : .clear))
                    .frame(width: 34, height: 34)

                Image(systemName: workspace.icon)
                    .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? KryptonColor.amber : (isHovering ? colors.textPrimary : colors.textMuted))
            }
            .overlay(alignment: .leading) {
                if isActive {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(KryptonColor.amber)
                        .frame(width: 2, height: 16)
                        .offset(x: -8)
                }
            }
        }
        .buttonStyle(.plain)
        .help(workspace.label)
        .onHover { hovering in
            withAnimation(PulseAnimation.easeOutFast) { isHovering = hovering }
        }
    }
}

// MARK: - Workspace Default Route

extension PrimaryWorkspace {
    var defaultRoute: AppRoute {
        switch self {
        case .tradingConsole: return .dashboard
        case .strategyLab: return .strategyWorkspace
        case .operations: return .agentPlatform
        }
    }
}

// MARK: - Krypton 六边形原子晶格 Logo

struct KryptonLogoView: View {
    var body: some View {
        ZStack {
            HexagonShape()
                .stroke(PulseColors.accent, lineWidth: 2.2)
                .frame(width: 24, height: 24)
                .shadow(color: PulseColors.accent.opacity(0.35), radius: 4)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let center = CGPoint(x: w / 2, y: h / 2)

                Path { path in
                    path.move(to: CGPoint(x: w / 2, y: 0))
                    path.addLine(to: center)
                    path.move(to: center)
                    path.addLine(to: CGPoint(x: w, y: h * 0.75))
                    path.move(to: center)
                    path.addLine(to: CGPoint(x: 0, y: h * 0.75))
                }
                .stroke(PulseColors.accent, lineWidth: 1.2)
            }
            .frame(width: 24, height: 24)

            Circle()
                .fill(KryptonColor.amberCenter)
                .frame(width: 4, height: 4)
                .shadow(color: KryptonColor.amberCenter.opacity(0.8), radius: 3)
        }
    }
}

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addLine(to: CGPoint(x: w, y: h * 0.25))
        path.addLine(to: CGPoint(x: w, y: h * 0.75))
        path.addLine(to: CGPoint(x: w / 2, y: h))
        path.addLine(to: CGPoint(x: 0, y: h * 0.75))
        path.addLine(to: CGPoint(x: 0, y: h * 0.25))
        path.closeSubpath()
        return path
    }
}
