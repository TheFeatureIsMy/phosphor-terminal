// PulseDeskApp.swift — 应用入口点
// 配置窗口样式、注入全局状态、注册快捷键

import SwiftUI

@main
struct PulseDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var appState = AppState()
    @State private var authState = AuthState()
    @State private var settingsState = SettingsState()
    @State private var errorHandler = ErrorHandler()
    @State private var wsManager = WebSocketManager()
    @State private var toastManager = ToastManager()
    private let themeManager: ThemeManager
    private let pulseColors: PulseColors
    private let dependencyState: DependencyState

    // NetworkClient 切换: 默认 Mock 模式，传入 --live 参数或设置 PULSEDESK_LIVE=1 环境变量切换到真实后端
    private static func makeNetworkClient() -> any NetworkClientProtocol {
        let args = ProcessInfo.processInfo.arguments
        let env = ProcessInfo.processInfo.environment
        if args.contains("--live") || env["PULSEDESK_LIVE"] == "1" {
            return LiveNetworkClient()
        }
        return MockNetworkClient()
    }

    @State private var networkClient: any NetworkClientProtocol = MockNetworkClient()

    init() {
        let tm = ThemeManager()
        self.themeManager = tm
        self.pulseColors = PulseColors(themeManager: tm)
        let client = Self.makeNetworkClient()
        self._networkClient = State(initialValue: client)
        self.dependencyState = DependencyState(client: client)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(authState)
                .environment(settingsState)
                .environment(themeManager)
                .environment(pulseColors)
                .environment(\.networkClient, networkClient)
                .environment(errorHandler)
                .environment(wsManager)
                .environment(toastManager)
                .environment(dependencyState as DependencyState?)
                .preferredColorScheme(themeManager.isDark ? .dark : .light)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.35), value: themeManager.current)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    // Mock 模式自动登录；Live 模式显示登录页
                    let isLive = ProcessInfo.processInfo.arguments.contains("--live")
                        || ProcessInfo.processInfo.environment["PULSEDESK_LIVE"] == "1"
                    if !isLive && !authState.isAuthenticated {
                        authState.mockLogin()
                    }
                    // 初始化设置同步
                    settingsState.configure(client: networkClient)
                }
                .task {
                    await dependencyState.load()
                    dependencyState.startPeriodicRefresh()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("命令面板") {
                    appState.showCommandPalette.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
    }
}

// MARK: - App Delegate — 确保 Dock 图标和 Cmd+Tab 切换正常
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 确保应用以 regular 策略运行，显示 Dock 图标并参与 Cmd+Tab 切换
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - 内容视图（启动页 → 登录 → 主界面）
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthState.self) private var authState
    @Environment(\.dependencyState) private var depState

    private var showSetupSheet: Bool {
        !UserDefaults.standard.bool(forKey: "setupCompleted")
            && (depState?.showSetupWizard ?? false)
    }

    var body: some View {
        Group {
            if !appState.hasLaunched {
                LandingView()
            } else if authState.isAuthenticated {
                AppShellView()
            } else {
                LoginPlaceholderView()
            }
        }
        .sheet(isPresented: Binding(
            get: { showSetupSheet },
            set: { _ in }
        )) {
            SetupWizardView()
        }
    }
}

// MARK: - 登录视图
struct LoginPlaceholderView: View {
    @Environment(AuthState.self) private var authState
    @Environment(PulseColors.self) private var colors
    @Environment(\.networkClient) private var networkClient
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: PulseSpacing.lg) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 48))
                    .foregroundStyle(PulseColors.accent)

                Text("PulseDesk")
                    .font(PulseFonts.displayTitle)
                    .foregroundStyle(colors.textPrimary)

                Text("AI 驱动的加密量化交易平台")
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textSecondary)

                // 登录表单
                VStack(spacing: PulseSpacing.md) {
                    PulseTextField(label: "邮箱", text: $email, placeholder: "trader@pulsedesk.io")
                    PulseSecureField(label: "密码", text: $password, placeholder: "输入密码")

                    if let error = authState.errorMessage {
                        Text(error)
                            .font(PulseFonts.caption)
                            .foregroundStyle(PulseColors.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ProofAlphaButton(title: authState.isLoading ? "登录中..." : "登录") {
                        Task {
                            await authState.login(email: email, password: password, client: networkClient)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(authState.isLoading || email.isEmpty || password.isEmpty)
                }
                .frame(maxWidth: 320)

                Divider()
                    .background(colors.border)
                    .frame(maxWidth: 200)

                // Mock 登录（开发模式快捷入口）
                Button("Mock 登录（开发模式）") {
                    authState.mockLogin()
                }
                .buttonStyle(.plain)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
            }
        }
    }
}

// MARK: - 色彩扩展 — Light/Dark 自动适配
extension Color {
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil, dynamicProvider: { traits in
            switch traits.bestMatch(from: [.darkAqua, .aqua]) {
            case .darkAqua: return NSColor(dark)
            default: return NSColor(light)
            }
        }))
    }
}
