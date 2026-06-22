// AlphaLoopApp.swift — AlphaLoop 应用入口点
// 配置窗口样式、注入全局状态、注册快捷键

import SwiftUI

@main
struct AlphaLoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var appState = AppState()
    @State private var authState = AuthState()
    @State private var settingsState = SettingsState.shared
    @State private var errorHandler = ErrorHandler()
    @State private var wsManager = WebSocketManager()
    @State private var toastManager = ToastManager()
    @State private var environmentReady = false
    @State private var environmentChecked = false
    private let themeManager: ThemeManager
    private let pulseColors: PulseColors
    private let dependencyState: DependencyState

    @State private var networkClient: any NetworkClientProtocol = LiveNetworkClient()
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
        } else if forceMode == "mock" {
            client = MockNetworkClient()
        } else {
            client = LiveNetworkClient()
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
                .task(id: appState.retryBackendTrigger) {
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
                NSLog("[AlphaLoop] Backend reachable — using Live mode")
                isLiveMode = true
                appState.isLiveMode = true
                appState.backendUnavailable = false
                wsManager.connectForLiveMode()
            } else {
                NSLog("[AlphaLoop] Backend unreachable")
                appState.backendUnavailable = true
                appState.isDetectingBackend = false
                return
            }
        } else if forcedMode == "live" {
            appState.isLiveMode = true
            wsManager.connectForLiveMode()
        }

        appState.isDetectingBackend = false

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

        // Set app icon from bundled .icns (SPM uses Bundle.module)
        if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = iconImage
        }
    }
}

// MARK: - 内容视图（环境检测 → 登录 → 主界面）
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthState.self) private var authState
    @Environment(\.dependencyState) private var depState

    @StateObject private var dockerService = DockerEnvironmentService()
    @State private var showEnvironmentSetup = false

    private var showSetupSheet: Bool {
        !UserDefaults.standard.bool(forKey: "setupCompleted")
            && (depState?.showSetupWizard ?? false)
    }

    var body: some View {
        Group {
            if showEnvironmentSetup {
                EnvironmentSetupView(dockerService: dockerService)
            } else if appState.backendUnavailable {
                BackendUnavailableView {
                    appState.backendUnavailable = false
                    appState.isDetectingBackend = true
                    appState.retryBackendTrigger += 1
                }
            } else if appState.isDetectingBackend {
                LandingView()
            } else if !appState.hasLaunched {
                LandingView()
            } else if authState.isAuthenticated {
                AppShellView()
            } else {
                LoginPlaceholderView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EnvironmentReady"))) { _ in
            showEnvironmentSetup = false
            appState.isDetectingBackend = false
        }
        .task {
            showEnvironmentSetup = true // 先显示启动中遮罩
            await dockerService.checkAllAndAutoStart()
            if dockerService.overallStatus() == .allHealthy {
                showEnvironmentSetup = false
                appState.isDetectingBackend = false
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
    @Environment(SettingsState.self) private var settings
    @Environment(\.networkClient) private var networkClient
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: PulseSpacing.lg) {
                AlphaLoopLogoView()
                    .frame(width: 56, height: 56)
                    .shadow(color: PulseColors.accent.opacity(0.35), radius: 14)

                if settings.language == .zhCN {
                    Text("弈机")
                        .font(PulseFonts.displayTitle)
                        .foregroundStyle(colors.textPrimary)
                    Text("AlphaLoop")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(PulseColors.accent)
                        .tracking(2)
                } else {
                    Text("AlphaLoop")
                        .font(PulseFonts.displayTitle)
                        .foregroundStyle(colors.textPrimary)
                    Text("弈机")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(PulseColors.accent)
                        .tracking(2)
                }

                Text(L10n.zh("AI 多 Agent 加密量化交易终端", en: "AI Multi-Agent Crypto Quant Trading Terminal"))
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
