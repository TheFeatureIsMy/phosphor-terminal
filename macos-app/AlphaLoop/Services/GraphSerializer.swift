// GraphSerializer.swift — 工作流图 JSON 序列化/反序列化
// 支持保存/加载 WorkflowGraph 到文件或 Data

import Foundation

struct GraphSerializer {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder = JSONDecoder()

    // MARK: - Data round-trip

    func serialize(_ graph: WorkflowGraph) throws -> Data {
        try encoder.encode(graph)
    }

    func deserialize(_ data: Data) throws -> WorkflowGraph {
        try decoder.decode(WorkflowGraph.self, from: data)
    }

    // MARK: - File round-trip

    func save(_ graph: WorkflowGraph, to url: URL) throws {
        let data = try serialize(graph)
        try data.write(to: url, options: .atomic)
    }

    func load(from url: URL) throws -> WorkflowGraph {
        let data = try Data(contentsOf: url)
        return try deserialize(data)
    }
}
