// DockerEnvironmentService.swift — 一键启动后端依赖栈
// 调用 docker compose up -d 在项目根目录，轮询各服务健康状态。
import Foundation

@MainActor
final class DockerEnvironmentService: ObservableObject {
    enum ServiceStatus: Equatable {
        case unknown
        case checking
        case notRunning
        case starting
        case healthy
        case failed(String)
    }

    enum OverallStatus: Equatable {
        case notInstalled
        case dockerNotRunning
        case notStarted
        case starting
        case partial
        case allHealthy
    }

    @Published var dockerInstalled: ServiceStatus = .unknown
    @Published var dockerRunning: ServiceStatus = .unknown
    @Published var postgresStatus: ServiceStatus = .unknown
    @Published var redisStatus: ServiceStatus = .unknown
    @Published var freqtradeStatus: ServiceStatus = .unknown
    @Published var apiStatus: ServiceStatus = .unknown
    @Published var lastLog: String = ""
    @Published var isStarting: Bool = false

    // 从 app bundle 路径推导项目根目录（.app 位于 macos-app/.build/arm64-apple-macosx/debug/）
    // 真实打包时，docker-compose.yml 随 app bundle 分发到 Resources
    private let projectRoot: String = {
        let bundleURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        // 向上 4 层: .build/xxx/debug/AlphaLoop.app → .build/xxx/debug → .build/xxx → .build → macos-app → phosphor-terminal
        var root = bundleURL
        for _ in 0..<4 { root = root.deletingLastPathComponent() }
        return root.path
    }()
    private var healthCheckTask: Task<Void, Never>?

    // MARK: - 全量检测 + 静默自动启动

    func checkAllAndAutoStart() async {
        async let d1 = checkDockerInstalled()
        async let d2 = checkDockerRunning()
        _ = await (d1, d2)

        // 自动启动 Docker（如果已安装但没运行）
        if case .healthy = dockerInstalled, case .notRunning = dockerRunning {
            lastLog = "正在启动 Docker..."
            do {
                _ = try await shell("open -a Docker 2>&1")
                for _ in 0..<15 { // 最多等 15 秒
                    try? await Task.sleep(for: .seconds(1))
                    await checkDockerRunning()
                    if case .healthy = dockerRunning { break }
                }
            } catch {
                lastLog = "Docker 启动失败"
            }
        }

        guard case .healthy = dockerRunning else { return }

        // 检测当前服务健康
        await checkAllServices()
        let healthyCount = [postgresStatus, redisStatus, freqtradeStatus, apiStatus]
            .filter { $0 == .healthy }.count

        // 如果服务不全，静默启动 compose
        if healthyCount < 4 && !isStarting {
            lastLog = "正在启动后端服务..."
            await startAll()
        }
    }

    func overallStatus() -> OverallStatus {
        if case .failed = dockerInstalled { return .notInstalled }
        if case .healthy = dockerInstalled, case .notRunning = dockerRunning { return .dockerNotRunning }
        if case .healthy = dockerRunning {
            let services = [postgresStatus, redisStatus, freqtradeStatus, apiStatus]
            let healthy = services.filter { $0 == .healthy }.count
            if healthy == 4 { return .allHealthy }
            if healthy > 0 { return .partial }
            if isStarting { return .starting }
            return .notStarted
        }
        return .notStarted
    }

    // MARK: - 一键启动

    func startAll() async {
        isStarting = true
        healthCheckTask?.cancel()
        healthCheckTask = Task { await healthCheckLoop() }
        do {
            postgresStatus = .starting
            redisStatus = .starting
            freqtradeStatus = .starting
            apiStatus = .starting
            _ = try await shell("cd \"\(projectRoot)\" && docker compose up -d --wait 2>&1")
            lastLog = "Compose 启动完成，等待服务健康..."
        } catch {
            lastLog = "启动失败: \(error.localizedDescription)"
            isStarting = false
        }
    }

    // MARK: - 检测方法

    private func checkDockerInstalled() async {
        dockerInstalled = .checking
        do {
            let out = try await shell("docker --version 2>&1")
            if out.lowercased().contains("docker") {
                dockerInstalled = .healthy
            } else {
                dockerInstalled = .failed("Docker 未找到")
            }
        } catch {
            dockerInstalled = .failed("Docker 未安装或不在 PATH 中")
        }
    }

    private func checkDockerRunning() async {
        guard case .healthy = dockerInstalled else {
            dockerRunning = .notRunning
            return
        }
        dockerRunning = .checking
        do {
            _ = try await shell("docker info > /dev/null 2>&1")
            dockerRunning = .healthy
        } catch {
            dockerRunning = .notRunning
        }
    }

    private func checkAllServices() async {
        async let p1 = checkPostgres()
        async let p2 = checkRedis()
        async let p3 = checkFreqtrade()
        async let p4 = checkAPI()
        _ = await (p1, p2, p3, p4)
    }

    private func checkPostgres() async {
        do {
            _ = try await shell("nc -z localhost 5432 2>&1 || /opt/homebrew/opt/netcat/bin/nc -z localhost 5432 2>&1 || /usr/bin/nc -z localhost 5432 2>&1 || true")
            // 也可以用 psql，但 nc 更轻量
            postgresStatus = .healthy
        } catch {
            postgresStatus = .notRunning
        }
    }

    private func checkRedis() async {
        do {
            _ = try await shell("nc -z localhost 6379 2>&1 || true")
            redisStatus = .healthy
        } catch {
            redisStatus = .notRunning
        }
    }

    private func checkFreqtrade() async {
        do {
            _ = try await shell("nc -z localhost 8080 2>&1 || true")
            freqtradeStatus = .healthy
        } catch {
            freqtradeStatus = .notRunning
        }
    }

    private func checkAPI() async {
        // 调用 health endpoint，非 2xx 算失败
        do {
            let script = """
            curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/health 2>/dev/null || echo "000"
            """
            let out = try await shell(script).trimmingCharacters(in: .whitespacesAndNewlines)
            if out.hasPrefix("2") {
                apiStatus = .healthy
            } else {
                apiStatus = .notRunning
            }
        } catch {
            apiStatus = .notRunning
        }
    }

    private func healthCheckLoop() async {
        for _ in 0..<60 { // 最多等 5 分钟
            guard isStarting else { break }
            await checkAllServices()
            // 当所有服务健康时退出
            if case .healthy = postgresStatus,
               case .healthy = redisStatus,
               case .healthy = freqtradeStatus,
               case .healthy = apiStatus {
                isStarting = false
                break
            }
            try? await Task.sleep(for: .seconds(5))
        }
        if isStarting { isStarting = false }
    }

    // MARK: - Helpers

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
