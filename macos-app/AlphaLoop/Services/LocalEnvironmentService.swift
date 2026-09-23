// LocalEnvironmentService.swift - 本机环境自动检测与启动
// 自动检测并启动 PostgreSQL、Redis、后端 API，用户无需手动操作。

import Foundation

@MainActor
final class LocalEnvironmentService: ObservableObject {
    enum ServiceStatus: Equatable {
        case unknown
        case checking
        case notRunning
        case starting
        case healthy
        case failed(String)
    }

    enum OverallStatus: Equatable {
        case notInstalled       // brew 或依赖未安装
        case notStarted         // 依赖已安装但服务未运行
        case starting           // 正在启动
        case partial            // 部分服务就绪
        case allHealthy         // 全部就绪
    }

    @Published var postgresStatus: ServiceStatus = .unknown
    @Published var redisStatus: ServiceStatus = .unknown
    @Published var apiStatus: ServiceStatus = .unknown
    @Published var lastLog: String = ""
    @Published var isStarting: Bool = false

    private var backendProcess: Process?
    private var healthCheckTask: Task<Void, Never>?
    private var backendProjectRoot: String = ""

    init() {
        // 推导项目根目录
        // swift run 模式: executable 在 .build/debug/AlphaLoop
        // .app 模式: executable 在 AlphaLoop.app/Contents/MacOS/AlphaLoop
        let execPath = CommandLine.arguments.first ?? Bundle.main.bundlePath
        var root = URL(fileURLWithPath: execPath)
        // 向上查找直到找到包含 phosphor-terminal 的路径
        for _ in 0..<10 {
            root = root.deletingLastPathComponent()
            let candidate = root.appendingPathComponent("phosphor-terminal")
            if FileManager.default.fileExists(atPath: candidate.path) {
                backendProjectRoot = root.path
                return
            }
        }
        // fallback
        backendProjectRoot = root.path
    }

    // MARK: - 全量检测 + 自动启动

    func checkAllAndAutoStart() async {
        lastLog = "正在检测环境..."
        async let p = checkPostgres()
        async let r = checkRedis()
        async let a = checkAPI()
        _ = await (p, r, a)

        let healthyCount = [postgresStatus, redisStatus, apiStatus]
            .filter { $0 == .healthy }.count

        if healthyCount < 3 && !isStarting {
            lastLog = "正在自动启动服务..."
            await startAll()
        } else if healthyCount == 3 {
            lastLog = "所有服务就绪"
        }
    }

    func overallStatus() -> OverallStatus {
        let services = [postgresStatus, redisStatus, apiStatus]
        let healthy = services.filter { $0 == .healthy }.count
        if healthy == 3 { return .allHealthy }
        if healthy > 0 { return .partial }
        if isStarting { return .starting }

        // 检查 brew 是否安装
        if postgresStatus == .failed("not_installed") || redisStatus == .failed("not_installed") {
            return .notInstalled
        }
        return .notStarted
    }

    // MARK: - 一键启动

    func startAll() async {
        isStarting = true
        healthCheckTask?.cancel()
        healthCheckTask = Task { await healthCheckLoop() }

        // 1. 启动 PostgreSQL
        if postgresStatus != .healthy {
            postgresStatus = .starting
            lastLog = "启动 PostgreSQL..."
            _ = try? await shell("brew services start postgresql@16 2>&1")
            try? await Task.sleep(for: .seconds(2))
            await checkPostgres()
            // 回退：brew services 不可用时直接 pg_ctl 启动
            if postgresStatus != .healthy {
                lastLog = "回退 pg_ctl 启动 PostgreSQL..."
                _ = try? await shell("pg_ctl -D /opt/homebrew/var/postgresql@16 -l /opt/homebrew/var/log/postgresql@16.log start 2>&1")
                try? await Task.sleep(for: .seconds(2))
                await checkPostgres()
            }
        }

        // 2. 启动 Redis
        if redisStatus != .healthy {
            redisStatus = .starting
            lastLog = "启动 Redis..."
            _ = try? await shell("brew services start redis 2>&1")
            try? await Task.sleep(for: .seconds(2))
            await checkRedis()
            // 回退：brew services 不可用时直接 daemonize 启动
            if redisStatus != .healthy {
                lastLog = "回退直接启动 Redis..."
                _ = try? await shell("redis-server --daemonize yes 2>&1")
                try? await Task.sleep(for: .seconds(1))
                await checkRedis()
            }
        }

        // 3. 启动后端 API
        if apiStatus != .healthy && postgresStatus == .healthy {
            apiStatus = .starting
            lastLog = "启动后端 API..."
            await startBackend()
        }

        // 等待 API 就绪
        for _ in 0..<30 {
            guard isStarting else { break }
            await checkAPI()
            if apiStatus == .healthy {
                isStarting = false
                lastLog = "所有服务就绪"
                break
            }
            try? await Task.sleep(for: .seconds(2))
        }
        if isStarting { isStarting = false }
    }

    // MARK: - 检测方法

    private func checkPostgres() async {
        postgresStatus = .checking
        // 优先探测 TCP 5432 端口连通性，兼容 Docker 容器 / 本机 brew 两种部署
        if await isPortOpen(5432) {
            postgresStatus = .healthy
            return
        }
        do {
            let out = try await shell("pg_isready 2>&1 || /opt/homebrew/opt/postgresql@16/bin/pg_isready 2>&1")
            if out.lowercased().contains("accepting") {
                postgresStatus = .healthy
            } else {
                postgresStatus = .notRunning
            }
        } catch {
            // 检查 brew 是否安装了 postgresql
            let brewCheck = try? await shell("brew list postgresql@16 2>&1")
            if brewCheck?.contains("Error") == true || brewCheck?.contains("not installed") == true {
                postgresStatus = .failed("not_installed")
            } else {
                postgresStatus = .notRunning
            }
        }
    }

    private func checkRedis() async {
        redisStatus = .checking
        // 优先探测 TCP 6379 端口连通性，兼容 Docker 容器 / 本机 brew 两种部署
        if await isPortOpen(6379) {
            redisStatus = .healthy
            return
        }
        do {
            let out = try await shell("redis-cli ping 2>&1 || /opt/homebrew/opt/redis/bin/redis-cli ping 2>&1")
            if out.uppercased().contains("PONG") {
                redisStatus = .healthy
            } else {
                redisStatus = .notRunning
            }
        } catch {
            let brewCheck = try? await shell("brew list redis 2>&1")
            if brewCheck?.contains("Error") == true || brewCheck?.contains("not installed") == true {
                redisStatus = .failed("not_installed")
            } else {
                redisStatus = .notRunning
            }
        }
    }

    private func checkAPI() async {
        apiStatus = .checking
        do {
            let out = try await shell("curl -s -o /dev/null -w \"%{http_code}\" http://127.0.0.1:8000/health 2>/dev/null || echo \"000\"")
            if out.hasPrefix("2") {
                apiStatus = .healthy
            } else {
                apiStatus = .notRunning
            }
        } catch {
            apiStatus = .notRunning
        }
    }

    // MARK: - 后端进程启动

    private func startBackend() async {
        // 先杀掉可能存在的旧进程
        _ = try? await shell("lsof -ti:8000 | xargs kill -9 2>/dev/null")
        try? await Task.sleep(for: .seconds(1))

        let backendDir = "\(backendProjectRoot)/phosphor-terminal/backend"
        guard FileManager.default.fileExists(atPath: backendDir) else {
            apiStatus = .failed("backend dir not found: \(backendDir)")
            return
        }

        // 查找 Python 可执行文件：优先 backend/.venv（依赖完整），其次系统 python3.11
        let venvPython = "\(backendDir)/.venv/bin/python"
        let pythonPath: String
        if FileManager.default.fileExists(atPath: venvPython) {
            pythonPath = venvPython
        } else if let whichResult = try? await shell("which python3.11 2>/dev/null"), !whichResult.isEmpty {
            pythonPath = whichResult.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            pythonPath = "/opt/homebrew/opt/python@3.11/bin/python3.11"
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: pythonPath)
        task.arguments = ["run.py"]
        task.currentDirectoryURL = URL(fileURLWithPath: backendDir)

        // 环境变量
        var env = ProcessInfo.processInfo.environment
        env["DATABASE_URL"] = "postgresql://pulsedesk:pulsedesk@localhost:5432/pulsedesk"
        env["REDIS_URL"] = "redis://localhost:6379/0"
        task.environment = env

        do {
            try task.run()
            backendProcess = task
            lastLog = "后端进程已启动 (PID: \(task.processIdentifier))"
        } catch {
            apiStatus = .failed("无法启动后端: \(error.localizedDescription)")
        }
    }

    private func healthCheckLoop() async {
        for _ in 0..<60 {
            guard isStarting else { break }
            await checkAPI()
            if case .healthy = apiStatus {
                isStarting = false
                break
            }
            try? await Task.sleep(for: .seconds(3))
        }
        if isStarting { isStarting = false }
    }

    // MARK: - 停止

    func stopBackend() {
        backendProcess?.terminate()
        backendProcess = nil
    }

    // MARK: - Shell Helper

    /// 探测本机某 TCP 端口是否可连通（兼容服务跑在 Docker 容器 / 本机的情况）
    private func isPortOpen(_ port: Int, host: String = "127.0.0.1") async -> Bool {
        let out = try? await shell("nc -z -G 1 \(host) \(port) >/dev/null 2>&1 && echo open || echo closed")
        return out?.contains("open") == true
    }

    private func shell(_ command: String) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/sh")
            task.arguments = ["-c", command]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            if task.terminationStatus != 0 {
                throw NSError(domain: "ShellError", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])
            }
            return output
        }.value
    }
}
