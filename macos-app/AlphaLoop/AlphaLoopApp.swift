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
        client = LiveNetworkClient()
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

        // 注册打包的 Protocol 字体(Space Grotesk / Inter)。
        Self.registerBundledFonts()

        // Set app icon from bundled .icns (SPM uses Bundle.module)
        if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = iconImage
        }

        // 修复窗口框架恢复崩坏：当前即主线程，先试一次
        Self.normalizeMainWindow()

        // SwiftUI 窗口在 didFinishLaunching 之后才创建/恢复，需延后再规范化
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.6))
            Self.normalizeMainWindow()
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: nil
        ) { _ in
            Task { @MainActor in Self.normalizeMainWindow() }
        }

        // 调试：--capture <path> 在数据加载后抓取自身窗口为 PNG（无需录屏权限）
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "--capture"), idx + 1 < args.count {
            let path = args[idx + 1]
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(7))
                Self.captureMainWindow(to: path)
            }
        }
    }

    /// 抓取主窗口内容到 PNG（只渲染本 app 自身窗口，不需要屏幕录制权限）。
    @MainActor
    static func captureMainWindow(to path: String) {
        guard let win = NSApp.mainWindow ?? NSApp.windows.first,
              let view = win.contentView else { return }
        view.layoutSubtreeIfNeeded()
        let rect = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: rect) else { return }
        view.cacheDisplay(in: rect, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
            NSLog("[AlphaLoop] captured window -> \(path)")
        }
    }

    /// 将主窗口拉回可见屏幕并规范尺寸（防止恢复出屏外/超小窗口）。
    @MainActor
    static func normalizeMainWindow() {
        let visible = NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        for window in NSApp.windows where window.canBecomeMain {
            window.isRestorable = false  // 禁止再次恢复坏 frame
            let f = window.frame
            let offScreen = !visible.intersects(f)
            let tooSmall = f.width < 900 || f.height < 600
            if offScreen || tooSmall {
                let w = min(1280, visible.width - 60)
                let h = min(840, visible.height - 60)
                window.setFrame(
                    NSRect(x: visible.midX - w / 2, y: visible.midY - h / 2, width: w, height: h),
                    display: true
                )
                window.center()
            }
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// SPM 可执行文件不会自动注册 bundle 内字体，需运行时手动注册。
    static func registerBundledFonts() {
        guard let fontsDir = Bundle.module.url(forResource: "Fonts", withExtension: nil) else { return }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: fontsDir, includingPropertiesForKeys: nil) else { return }
        for url in files where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                NSLog("[AlphaLoop] Font register failed: \(url.lastPathComponent)")
            }
        }
    }
}

// MARK: - 内容视图（环境检测 → 登录 → 主界面）
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthState.self) private var authState
    @Environment(\.dependencyState) private var depState

    @StateObject private var envService = LocalEnvironmentService()
    @State private var showEnvironmentSetup = false

    private var showSetupSheet: Bool {
        !UserDefaults.standard.bool(forKey: "setupCompleted")
            && (depState?.showSetupWizard ?? false)
    }

    var body: some View {
        Group {
            if showEnvironmentSetup {
                EnvironmentSetupView(envService: envService)
            } else if appState.isDetectingBackend {
                LandingView()
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
            } else {
                // 登录已移除：后端就绪后直接进入主界面。
                AppShellView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EnvironmentReady"))) { _ in
            showEnvironmentSetup = false
            appState.isDetectingBackend = false
        }
        .task {
            showEnvironmentSetup = true
            appState.isDetectingBackend = true
            appState.backendUnavailable = false
            await envService.checkAllAndAutoStart()
            if envService.overallStatus() == .allHealthy {
                showEnvironmentSetup = false
                appState.isDetectingBackend = false
                appState.retryBackendTrigger += 1
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
                        .foregroundStyle(PulseColors.accentText)
                        .tracking(2)
                } else {
                    Text("AlphaLoop")
                        .font(PulseFonts.displayTitle)
                        .foregroundStyle(colors.textPrimary)
                    Text("弈机")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(PulseColors.accentText)
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
