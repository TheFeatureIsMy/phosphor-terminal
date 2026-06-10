// UserGuide.swift — 打开本地用户指南站点
//
// 用户指南是一个静态站点 (docs/user-guide/) ，章节通过 fetch() 异步加载。
// file:// 协议下浏览器禁止 fetch 本地资源 (CORS) ，所以必须用一个本地 HTTP server 提供。
//
// 流程：
//   1. 检查 4178 端口是否已经有 server (我们之前启的，或者用户自己跑的)
//   2. 没有就 spawn `python3 -m http.server 4178` 在 docs/user-guide/ 目录
//   3. 等端口起来，打开 http://localhost:4178/#/<anchor>
//   4. app 退出时把 server 干掉

import AppKit
import Foundation

@MainActor
enum UserGuide {
    /// 用户指南站点中的锚点路径，对应 hash 路由（不带 `#/`）。
    enum Anchor: String {
        case welcome           = "welcome"
        case concepts          = "concepts/01-what-is-quant"
        case firstStrategy     = "walkthroughs/first-strategy"
        case dailyTradingLoop  = "walkthroughs/daily-trading-loop"
    }

    private static let port: Int = 4178
    private static var serverProcess: Process?
    private static var terminationObserver: NSObjectProtocol?

    /// 打开指南站点。anchor 为 nil 时打开首页。
    @discardableResult
    static func open(anchor: Anchor? = nil) -> Bool {
        guard ensureServerRunning() else { return false }

        var components = URLComponents()
        components.scheme = "http"
        components.host = "localhost"
        components.port = port
        components.path = "/"
        if let anchor { components.fragment = "/\(anchor.rawValue)" }

        guard let url = components.url else { return false }
        return NSWorkspace.shared.open(url)
    }

    // MARK: - Server lifecycle

    private static func ensureServerRunning() -> Bool {
        if isServerLive() { return true }

        guard let guideDir = locateGuideDirectory() else {
            NSLog("[UserGuide] could not locate docs/user-guide directory")
            return false
        }
        guard let python = locatePython() else {
            NSLog("[UserGuide] python3 not found in known locations")
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

        // python http.server binds within ~100ms; poll up to 2s
        for _ in 0..<20 {
            Thread.sleep(forTimeInterval: 0.1)
            if isServerLive() { return true }
        }

        // didn't come up — kill the orphan and bail
        process.terminate()
        serverProcess = nil
        return false
    }

    /// 同步 HTTP GET 探测端口；超时 0.4s
    private static func isServerLive() -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port)/index.html") else { return false }
        let semaphore = DispatchSemaphore(value: 0)
        let result = ProbeResult()

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 0.4
        config.timeoutIntervalForResource = 0.4
        let session = URLSession(configuration: config)

        let task = session.dataTask(with: url) { _, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                result.ok = true
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 0.6)
        return result.ok
    }

    private final class ProbeResult: @unchecked Sendable {
        var ok = false
    }

    private static func registerTerminationCleanup() {
        guard terminationObserver == nil else { return }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                if let p = serverProcess, p.isRunning {
                    p.terminate()
                }
            }
        }
    }

    // MARK: - Location helpers

    private static func locatePython() -> String? {
        let candidates = [
            "/usr/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    private static func locateGuideDirectory() -> URL? {
        // 1) bundle (future: when guide gets shipped inside the app)
        if let bundled = Bundle.main.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "user-guide"
        ) {
            return bundled.deletingLastPathComponent()
        }

        // 2) walk up from executable + cwd looking for docs/user-guide/index.html
        for root in candidateRepoRoots() {
            let dir = root
                .appendingPathComponent("docs")
                .appendingPathComponent("user-guide")
            let index = dir.appendingPathComponent("index.html")
            if FileManager.default.fileExists(atPath: index.path) {
                return dir
            }
        }
        return nil
    }

    private static func candidateRepoRoots() -> [URL] {
        var roots: [URL] = []

        if let executable = Bundle.main.executableURL {
            var dir = executable.deletingLastPathComponent()
            for _ in 0..<10 {
                roots.append(dir)
                dir = dir.deletingLastPathComponent()
            }
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var dir = cwd
        for _ in 0..<10 {
            roots.append(dir)
            dir = dir.deletingLastPathComponent()
        }

        return roots
    }
}
