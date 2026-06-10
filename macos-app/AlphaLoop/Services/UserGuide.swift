// UserGuide.swift — 打开本地用户指南站点
//
// 用户指南是一个静态站点 (docs/user-guide/)。
// file:// 下浏览器禁止 fetch 本地资源，所以用 python3 http.server 提供。

import AppKit
import Foundation

@MainActor
enum UserGuide {
    enum Anchor: String {
        case welcome           = "welcome"
        case concepts          = "concepts/01-what-is-quant"
        case firstStrategy     = "walkthroughs/first-strategy"
        case dailyTradingLoop  = "walkthroughs/daily-trading-loop"
    }

    private static let port: Int = 4178
    private static var serverProcess: Process?
    private static var terminationObserver: NSObjectProtocol?
    private(set) static var isStarting = false

    @discardableResult
    static func open(anchor: Anchor? = nil) -> Bool {
        guard !isStarting else { return true }

        if isServerLiveSync() {
            return openBrowser(anchor: anchor)
        }

        isStarting = true
        Task {
            let success = await startServerAsync()
            isStarting = false
            if success {
                openBrowser(anchor: anchor)
            } else {
                NSLog("[UserGuide] failed to start server")
            }
        }
        return true
    }

    @discardableResult
    private static func openBrowser(anchor: Anchor? = nil) -> Bool {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "localhost"
        components.port = port
        components.path = "/"
        if let anchor { components.fragment = "/\(anchor.rawValue)" }
        guard let url = components.url else { return false }
        return NSWorkspace.shared.open(url)
    }

    // MARK: - Async server startup

    private static func startServerAsync() async -> Bool {
        guard let guideDir = locateGuideDirectory() else {
            NSLog("[UserGuide] could not locate docs/user-guide directory")
            return false
        }
        guard let python = locatePython() else {
            NSLog("[UserGuide] python3 not found")
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: python)
        process.arguments = ["-m", "http.server", "\(port)", "--bind", "127.0.0.1"]
        process.currentDirectoryURL = guideDir
        process.standardOutput = FileHandle.nullDevice
        process.standardError  = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            NSLog("[UserGuide] failed to start http.server: \(error)")
            return false
        }

        serverProcess = process
        registerTerminationCleanup()

        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(100))
            if await checkServerLive() { return true }
        }

        process.terminate()
        serverProcess = nil
        return false
    }

    private static func checkServerLive() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port)/index.html") else { return false }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 0.5
        let session = URLSession(configuration: config)
        do {
            let (_, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                return true
            }
        } catch {}
        return false
    }

    /// Quick non-blocking check (for when server might already be running)
    private static func isServerLiveSync() -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }

    private static func registerTerminationCleanup() {
        guard terminationObserver == nil else { return }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            if let p = serverProcess, p.isRunning {
                p.terminate()
            }
        }
    }

    // MARK: - Location helpers

    private static func locatePython() -> String? {
        for path in ["/usr/bin/python3", "/opt/homebrew/bin/python3", "/usr/local/bin/python3"] {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }

    private static func locateGuideDirectory() -> URL? {
        if let bundled = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "user-guide") {
            return bundled.deletingLastPathComponent()
        }

        for root in candidateRepoRoots() {
            let index = root.appendingPathComponent("docs/user-guide/index.html")
            if FileManager.default.fileExists(atPath: index.path) {
                return index.deletingLastPathComponent()
            }
        }
        return nil
    }

    private static func candidateRepoRoots() -> [URL] {
        var roots: [URL] = []

        if let executable = Bundle.main.executableURL {
            var dir = executable.deletingLastPathComponent()
            for _ in 0..<12 {
                roots.append(dir)
                dir = dir.deletingLastPathComponent()
            }
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var dir = cwd
        for _ in 0..<8 {
            roots.append(dir)
            dir = dir.deletingLastPathComponent()
        }

        // Direct known path as last resort
        let home = FileManager.default.homeDirectoryForCurrentUser
        roots.append(home.appendingPathComponent("workspace/phosphor-terminal"))

        return roots
    }
}
