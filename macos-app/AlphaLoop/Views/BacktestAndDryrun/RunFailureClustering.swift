// RunFailureClustering.swift — Pure function for run-level failure clustering
// Buckets losing trades by duration, producing at most 5 RunFailureCluster values.
// Note: This is a pure function intentionally free of L10n calls (which require
// MainActor). View layer should map feature keys to localized strings.

import Foundation

public struct RunFailureCluster: Identifiable, Hashable {
    public let id: String
    public let label: String
    public let sampleSize: Int
    public let totalLoss: Double
    public let avgLoss: Double
    public let commonFeatures: [String]
}

private func durationBucket(_ d: String) -> String {
    let lower = d.lowercased()
    if lower.contains("m") && !lower.contains("h") { return "<1h" }
    if let h = Double(lower.replacingOccurrences(of: "h", with: "")) {
        switch h {
        case ..<1: return "<1h"
        case 1..<4: return "1-4h"
        case 4..<12: return "4-12h"
        case 12..<24: return "12-24h"
        default: return ">24h"
        }
    }
    return "unknown"
}

private func hourBucket(_ openTime: String) -> String {
    if let t = ISO8601DateFormatter().date(from: openTime) {
        let h = Calendar.current.component(.hour, from: t)
        switch h {
        case 0..<6: return "00-06"
        case 6..<12: return "06-12"
        case 12..<18: return "12-18"
        default: return "18-24"
        }
    }
    return "unknown"
}

func clusterFailures(in trades: [TradeRow]) -> [RunFailureCluster] {
    let losses = trades.filter { $0.profit < 0 }
    if losses.count < 5 { return [] }

    // Cluster by duration bucket (most stable feature)
    var buckets: [String: [TradeRow]] = [:]
    for t in losses {
        let key = durationBucket(t.duration)
        buckets[key, default: []].append(t)
    }

    let clusters = buckets.map { (key, items) -> RunFailureCluster in
        let total = items.reduce(0.0) { $0 + $1.profit }
        let sides = Set(items.map { $0.side })
        let pairs = Set(items.map { $0.pair })
        let hours = Set(items.map { hourBucket($0.openTime) })
        var features: [String] = ["duration: \(key)"]
        if sides.count == 1 { features.append("side: \(sides.first!)") }
        if pairs.count == 1 { features.append("pair: \(pairs.first!)") }
        if hours.count == 1 { features.append("hour: \(hours.first!)") }
        return RunFailureCluster(
            id: key, label: key, sampleSize: items.count,
            totalLoss: total, avgLoss: total / Double(items.count),
            commonFeatures: features
        )
    }.sorted { $0.sampleSize > $1.sampleSize }

    return Array(clusters.prefix(5))
}
