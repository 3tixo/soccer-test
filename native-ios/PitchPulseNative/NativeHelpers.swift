import Foundation
import SwiftUI

struct MatchTeams {
    let home: Competitor?
    let away: Competitor?
}

extension ScoreEvent {
    var matchTeams: MatchTeams {
        let competitors = competition?.competitors ?? []
        return MatchTeams(
            home: competitors.first(where: { $0.homeAway == "home" }) ?? competitors.first,
            away: competitors.first(where: { $0.homeAway == "away" }) ?? competitors.dropFirst().first
        )
    }
}

extension Array where Element == TimelineEvent {
    var sortedByClock: [TimelineEvent] {
        sorted { first, second in
            let firstValue = first.clock?.value ?? first.time?.value ?? 0
            let secondValue = second.clock?.value ?? second.time?.value ?? 0
            if firstValue != secondValue {
                return firstValue < secondValue
            }
            return first.stableId < second.stableId
        }
    }
}

extension GameStatistic {
    var numericValue: Double {
        if let value {
            return max(value, 0)
        }

        let text = displayValue?
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: "") ?? ""

        return max(Double(text) ?? 0, 0)
    }
}

func statMap(_ stats: [GameStatistic]?) -> [String: GameStatistic] {
    Dictionary(uniqueKeysWithValues: (stats ?? []).compactMap { stat in
        guard let name = stat.name else { return nil }
        return (name, stat)
    })
}

func displayValue(_ stat: GameStatistic, suffix: String = "") -> String {
    guard let display = stat.displayValue, !display.isEmpty else {
        return "-"
    }
    if !suffix.isEmpty && !display.contains(suffix) {
        return "\(display)\(suffix)"
    }
    return display
}

func kickoffTime(_ isoDate: String?) -> String {
    guard let isoDate else { return "TBA" }
    let formatter = ISO8601DateFormatter()
    guard let date = formatter.date(from: isoDate) else { return "TBA" }
    return date.formatted(date: .omitted, time: .shortened)
}

func shortDate(_ isoDate: String?) -> String {
    guard let isoDate else { return "TBA" }
    let formatter = ISO8601DateFormatter()
    guard let date = formatter.date(from: isoDate) else { return "TBA" }
    return date.formatted(.dateTime.month(.abbreviated).day())
}

func ordinal(_ value: String) -> String {
    guard let number = Int(value) else { return value }
    let mod100 = number % 100
    if (11...13).contains(mod100) {
        return "\(number)th"
    }

    switch number % 10 {
    case 1: return "\(number)st"
    case 2: return "\(number)nd"
    case 3: return "\(number)rd"
    default: return "\(number)th"
    }
}

func decimalOdds(_ value: FlexibleOddsValue?) -> String {
    guard let value else { return "" }

    switch value {
    case .number(let number):
        return formatDecimal(americanToDecimal(number))
    case .text(let text):
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let number = Double(trimmed), trimmed.hasPrefix("+") || trimmed.hasPrefix("-") {
            return formatDecimal(americanToDecimal(number))
        }

        let parts = trimmed.split(separator: "/")
        if parts.count == 2, let numerator = Double(parts[0]), let denominator = Double(parts[1]), denominator != 0 {
            return formatDecimal(1 + numerator / denominator)
        }

        if let number = Double(trimmed) {
            return formatDecimal(number)
        }

        return trimmed
    }
}

private func americanToDecimal(_ value: Double) -> Double {
    value > 0 ? 1 + value / 100 : 1 + 100 / abs(value)
}

private func formatDecimal(_ value: Double) -> String {
    guard value.isFinite else { return "" }
    return String(format: value < 1.01 ? "%.3f" : "%.2f", value)
}
