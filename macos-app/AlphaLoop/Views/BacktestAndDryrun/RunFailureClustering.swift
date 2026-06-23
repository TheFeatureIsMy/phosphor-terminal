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
    var hours: Double = 0

    // Try HH:MM:SS or H:MM:SS
    let parts = lower.split(separator: ":")
    if parts.count >= 2, let h = Double(parts[0]), let m = Double(parts[1]) {
        hours = h + m / 60.0
    } else if lower.contains("day") {
        // "1 day, 02:00:00" or "1 day"
        let segments = lower.components(separatedBy: ",")
        if let dayPart = segments.first,
           let dayStr = dayPart.split(separator: " ").first,
           let d = Double(dayStr) {
            hours = d * 24
        }
        if segments.count > 1 {
            let timePart = segments[1].trimmingCharacters(in: .whitespaces)
            let subParts = timePart.split(separator: ":")
            if subParts.count >= 2, let h = Double(subParts[0]), let m = Double(subParts[1]) {
                hours += h + m / 60.0
            }
        }
    } else {
        // Plain "2.5h" or "30m"
        let stripped = lower.replacingOccurrences(of: " ", with: "")
        if stripped.hasSuffix("h") {
            hours = Double(stripped.dropLast()) ?? 0
        } else if stripped.hasSuffix("m") {
            hours = (Double(stripped.dropLast()) ?? 0) / 60.0
        } else if stripped.hasSuffix("d") {
            hours = (Double(stripped.dropLast()) ?? 0) * 24
        } else {
            return "unknown"
        }
    }

    switch hours {
    case ..<1: return "<1h"
    case 1..<4: return "1-4h"
    case 4..<12: return "4-12h"
    case 12..<24: return "12-24h"
    default: return ">24h"
    }
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
