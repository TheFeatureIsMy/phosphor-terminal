// PulseDeskApp.swift — 应用入口点
// 配置窗口样式、注入全局状态、注册快捷键

import SwiftUI

@main
struct PulseDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var appState = AppState()
    @State private var authState = AuthState()
    @State private var settingsState = SettingsState.shared
    @State private var errorHandler = ErrorHandler()
    @State private var wsManager = WebSocketManager()
    @State private var toastManager = ToastManager()
    private let themeManager: ThemeManager
    private let pulseColors: PulseColors
    private let dependencyState: DependencyState

    @State private var networkClient: any NetworkClientProtocol = MockNetworkClient()
    @State private var isDetectingBackend = true
    @State private var isLiveMode = false

    private static func resolveForceMode() -> String? {
        let args = ProcessInfo.processInfo.arguments
        let env  = ProcessInfo.processInfo.environment
        if args.contains("--live")  { return "live" }
        if args.contains("--mock")  { return "mock" }
        if env["PULSEDESK_LIVE"] == "1" { return "live" }
        return nil
    }

    init() {
        let tm = ThemeManager()
        self.themeManager = tm
        self.pulseColors = PulseColors(themeManager: tm)

        let forceMode = Self.resolveForceMode()
        let client: any NetworkClientProtocol
        if forceMode == "live" {
            client = LiveNetworkClient()
            self._isLiveMode = State(initialValue: true)
            self._isDetectingBackend = State(initialValue: false)
        } else if forceMode == "mock" {
            client = MockNetworkClient()
            self._isDetectingBackend = State(initialValue: false)
        } else {
            client = MockNetworkClient()
        }
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
                .task {
                    await detectBackendAndConfigure()
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

    private func detectBackendAndConfigure() async {
        let forcedMode = Self.resolveForceMode()

        if forcedMode == nil {
            let reachable = await LiveNetworkClient.isBackendReachable()
            if reachable {
                NSLog("[PulseDesk] Backend reachable — using Live mode")
                networkClient = LiveNetworkClient()
                isLiveMode = true
                appState.isLiveMode = true
                wsManager.connectForLiveMode()
            } else {
                NSLog("[PulseDesk] Backend unreachable — using Mock mode")
            }
        } else if forcedMode == "live" {
            appState.isLiveMode = true
            wsManager.connectForLiveMode()
        }

        isDetectingBackend = false

        // Auto-login in mock mode
        if !isLiveMode && !authState.isAuthenticated {
            authState.mockLogin()
        }

        // Initialize settings sync
        settingsState.configure(client: networkClient)

        // Load dependencies
        await dependencyState.load()
        dependencyState.startPeriodicRefresh()
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
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

                Text(L10n.zh("AI 驱动的加密量化交易平台", en: "AI-Powered Crypto Quant Trading Platform"))
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textSecondary)

                VStack(spacing: PulseSpacing.md) {
                    PulseTextField(label: L10n.Settings.email, text: $email, placeholder: "trader@pulsedesk.io")
                    PulseSecureField(label: L10n.zh("密码", en: "Password"), text: $password, placeholder: L10n.zh("输入密码", en: "Enter password"))

                    if let error = authState.errorMessage {
                        Text(error)
                            .font(PulseFonts.caption)
                            .foregroundStyle(PulseColors.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    KryptonButton(title: authState.isLoading ? L10n.Common.loading : L10n.zh("登录", en: "Sign In")) {
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

                Button("Mock Login (Dev Mode)") {
                    authState.mockLogin()
                }
                .buttonStyle(.plain)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
            }
        }
    }
}

// MARK: - 色彩扩展
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
