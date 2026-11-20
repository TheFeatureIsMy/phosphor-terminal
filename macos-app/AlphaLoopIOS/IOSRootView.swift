import SwiftUI

struct IOSRootView: View {
    @State private var authState = AuthState(authenticated: false)
    @State private var booting = true
    private let client: LiveNetworkClient

    init() {
        self.client = LiveNetworkClient(baseURL: IOSConfig.apiBaseURL)
    }

    var body: some View {
        Group {
            if booting {
                ProgressView("恢复会话…")
            } else if authState.isAuthenticated {
                TabView {
                    IOSDashboardView(client: client, onLogout: authState.logout)
                        .tabItem { Label("总览", systemImage: "chart.line.uptrend.xyaxis") }
                    IOSStrategiesView(client: client)
                        .tabItem { Label("策略", systemImage: "square.stack.3d.up") }
                    IOSExecutionView(client: client)
                        .tabItem { Label("执行", systemImage: "bolt.horizontal") }
                    IOSRiskView(client: client)
                        .tabItem { Label("风控", systemImage: "shield.lefthalf.filled") }
                    IOSSettingsView(client: client, onLogout: authState.logout)
                        .tabItem { Label("设置", systemImage: "gearshape") }
                }
            } else {
                IOSLoginView(authState: authState, client: client)
            }
        }
        .tint(IOSTheme.accent)
        .preferredColorScheme(.dark)
        .task {
            await authState.restoreSession(client: client)
            #if DEBUG
            if !authState.isAuthenticated,
               let email = UserDefaults.standard.string(forKey: "autoLoginEmail"),
               let password = UserDefaults.standard.string(forKey: "autoLoginPassword") {
                await authState.login(email: email, password: password, client: client)
            }
            #endif
            booting = false
        }
    }
}
