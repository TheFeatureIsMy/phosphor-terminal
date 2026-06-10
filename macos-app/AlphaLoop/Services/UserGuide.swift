// UserGuide.swift — 打开本地用户指南站点
//
// v1: 优先从仓库相对路径打开 docs/user-guide/index.html。
// 若运行环境找不到（例如未来打包发布），回退到 GitHub Pages（待发布）或失败。

import AppKit
import Foundation

enum UserGuide {
    /// 用户指南站点中的锚点路径，对应 hash 路由（不带 `#/`）。
    enum Anchor: String {
        case welcome           = "welcome"
        case concepts          = "concepts/01-what-is-alphaloop"
        case firstStrategy     = "walkthroughs/first-strategy"
        case dailyTradingLoop  = "walkthroughs/daily-trading-loop"
    }

    /// 打开指南站点。anchor 为 nil 时打开首页。
    /// 返回是否成功打开。
    @discardableResult
    static func open(anchor: Anchor? = nil) -> Bool {
        guard let url = resolveURL(anchor: anchor) else { return false }
        return NSWorkspace.shared.open(url)
    }

    // MARK: - URL resolution

    private static func resolveURL(anchor: Anchor?) -> URL? {
        let base = locateIndexHTML()
        guard let base else { return nil }

        guard let anchor else { return base }

        // 用 fragment 形式拼接 hash 路由：file://.../index.html#/path
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.fragment = "/\(anchor.rawValue)"
        return components?.url ?? base
    }

    private static func locateIndexHTML() -> URL? {
        // 1) 优先尝试 bundle 内的 Resources（未来若打包进 app）
        if let bundled = Bundle.main.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "user-guide"
        ) {
            return bundled
        }

        // 2) 从可执行文件路径回溯找仓库根
        for candidate in candidateRepoRoots() {
            let path = candidate
                .appendingPathComponent("docs")
                .appendingPathComponent("user-guide")
                .appendingPathComponent("index.html")
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }

        return nil
    }

    private static func candidateRepoRoots() -> [URL] {
        var roots: [URL] = []

        // 从 main bundle 可执行文件向上找
        if let executable = Bundle.main.executableURL {
            var dir = executable.deletingLastPathComponent()
            for _ in 0..<10 {
                roots.append(dir)
                dir = dir.deletingLastPathComponent()
            }
        }

        // 从当前工作目录向上找（swift run 场景）
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var dir = cwd
        for _ in 0..<10 {
            roots.append(dir)
            dir = dir.deletingLastPathComponent()
        }

        return roots
    }
}
