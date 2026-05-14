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
