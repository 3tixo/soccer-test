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
    var mapped: [String: GameStatistic] = [:]
    for stat in stats ?? [] {
        guard let name = stat.name else { continue }
        mapped[name] = stat
    }
    return mapped
}

func standingStatMap(_ stats: [StandingStat]?) -> [String: StandingStat] {
    var mapped: [String: StandingStat] = [:]
    for stat in stats ?? [] {
        guard let name = stat.name else { continue }
        mapped[name] = stat
    }
    return mapped
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

struct FormationRow: Identifiable {
    let line: String
    let players: [RosterPlayer]

    var id: String {
        line
    }
}

func formationRows(for players: [RosterPlayer], formation: String?) -> [FormationRow] {
    let starters = players.filter { $0.starter == true }
    if !usesBroadProviderPositions(starters) {
        let positionRows = formationRowsFromPositions(starters)
        if positionRows.count >= 3 {
            return positionRows
        }
    }

    let ordered = starters.sorted {
        ($0.formationPlace ?? 99) < ($1.formationPlace ?? 99)
    }
    let counts = formationCounts(formation: formation, starterCount: ordered.count)
    var cursor = 0

    return counts.enumerated().compactMap { index, count in
        guard count > 0 else { return nil }
        let end = min(cursor + count, ordered.count)
        guard cursor < end else { return nil }
        let rowPlayers = Array(ordered[cursor..<end]).sorted(by: lineupPlayerSort)
        cursor = end
        return FormationRow(line: formationLineName(index: index, total: counts.count), players: rowPlayers)
    }
}

private func formationRowsFromPositions(_ starters: [RosterPlayer]) -> [FormationRow] {
    let lines = ["goalkeeper", "defenders", "midfielders", "attacking-midfielders", "forwards"]
    let grouped = Dictionary(grouping: starters) { playerLine($0) }

    return lines.compactMap { line in
        let players = (grouped[line] ?? []).sorted(by: lineupPlayerSort)
        return players.isEmpty ? nil : FormationRow(line: line, players: players)
    }
}

private func formationCounts(formation: String?, starterCount: Int) -> [Int] {
    let parts = (formation ?? "")
        .split(separator: "-")
        .compactMap { Int($0) }
        .filter { $0 > 0 }
    let counts = [1] + parts
    if counts.reduce(0, +) == starterCount {
        return counts
    }
    if starterCount == 11 {
        return [1, 4, 3, 3]
    }
    return [1, max(starterCount - 1, 0)].filter { $0 > 0 }
}

private func usesBroadProviderPositions(_ players: [RosterPlayer]) -> Bool {
    let broad = Set(["G", "D", "M", "F", "GK", "CB", "CM", "ST"])
    let labels = players.compactMap { player -> String? in
        let raw = player.position?.abbreviation ?? player.position?.displayName
        return raw?.uppercased()
    }
    return !labels.isEmpty && labels.allSatisfy { broad.contains($0) }
}

private func formationLineName(index: Int, total: Int) -> String {
    if index == 0 { return "goalkeeper" }
    if index == 1 { return "defenders" }
    if index == total - 1 { return "forwards" }
    if total >= 5 && index == total - 2 { return "attacking-midfielders" }
    return "midfielders"
}

func positionLabel(for player: RosterPlayer, rowLine: String, index: Int, count: Int) -> String {
    let exact = normalizePositionLabel(player.position?.abbreviation, displayName: player.position?.displayName)
    if !exact.isEmpty && exact != "SUB" {
        return exact
    }
    return inferredPositionLabel(rowLine: rowLine, index: index, count: count)
}

func playerLine(_ player: RosterPlayer) -> String {
    let label = normalizePositionLabel(player.position?.abbreviation, displayName: player.position?.displayName)
    if label == "GK" { return "goalkeeper" }
    if ["LB", "LWB", "LCB", "CB", "RCB", "RB", "RWB"].contains(label) { return "defenders" }
    if ["CDM", "LCM", "CM", "RCM", "LM", "RM"].contains(label) { return "midfielders" }
    if ["LW", "CAM", "RW"].contains(label) { return "attacking-midfielders" }
    if ["ST", "CF"].contains(label) { return "forwards" }

    let text = (player.position?.displayName ?? "").lowercased()
    if text.contains("goalkeeper") { return "goalkeeper" }
    if text.contains("back") || text.contains("defender") { return "defenders" }
    if text.contains("attacking midfielder") || text.contains("winger") { return "attacking-midfielders" }
    if text.contains("midfielder") { return "midfielders" }
    if text.contains("forward") || text.contains("striker") { return "forwards" }
    return "midfielders"
}

private func normalizePositionLabel(_ abbreviation: String?, displayName: String?) -> String {
    let raw = (abbreviation?.isEmpty == false ? abbreviation : displayName) ?? ""
    let value = raw.uppercased()
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "-", with: "")

    let mapped = [
        "G": "GK",
        "KEEPER": "GK",
        "GOALIE": "GK",
        "GOALKEEPER": "GK",
        "D": "CB",
        "DF": "CB",
        "DEFENDER": "CB",
        "M": "CM",
        "MF": "CM",
        "MIDFIELDER": "CM",
        "F": "ST",
        "FW": "ST",
        "FORWARD": "ST",
        "STRIKER": "ST",
        "LEFTBACK": "LB",
        "RIGHTBACK": "RB",
        "FULLBACK": "CB",
        "CENTERBACK": "CB",
        "CENTREBACK": "CB",
        "CENTRALDEFENDER": "CB",
        "LEFTCENTERBACK": "LCB",
        "LEFTCENTREBACK": "LCB",
        "RIGHTCENTERBACK": "RCB",
        "RIGHTCENTREBACK": "RCB",
        "LEFTWINGBACK": "LWB",
        "RIGHTWINGBACK": "RWB",
        "DM": "CDM",
        "DEFENSIVEMIDFIELDER": "CDM",
        "AM": "CAM",
        "ATTACKINGMIDFIELDER": "CAM",
        "LEFTMIDFIELDER": "LM",
        "RIGHTMIDFIELDER": "RM",
        "LEFTWINGER": "LW",
        "RIGHTWINGER": "RW",
        "WINGER": "RW",
        "CENTREFORWARD": "ST",
        "CENTERFORWARD": "ST"
    ]

    return mapped[value] ?? value
}

private func inferredPositionLabel(rowLine: String, index: Int, count: Int) -> String {
    let labels: [String]
    switch rowLine {
    case "goalkeeper":
        labels = ["GK"]
    case "defenders":
        labels = count == 3 ? ["LCB", "CB", "RCB"] : count == 5 ? ["LWB", "CB", "CB", "CB", "RWB"] : ["LB", "CB", "CB", "RB"]
    case "attacking-midfielders":
        labels = count == 1 ? ["CAM"] : count == 2 ? ["CAM", "CAM"] : ["LW", "CAM", "RW"]
    case "forwards":
        labels = count == 1 ? ["ST"] : count == 2 ? ["ST", "ST"] : ["LW", "ST", "RW"]
    default:
        labels = count == 1 ? ["CDM"] : count == 2 ? ["CM", "CM"] : count == 4 ? ["LM", "CM", "CM", "RM"] : ["LCM", "CM", "RCM"]
    }
    return labels[min(index, labels.count - 1)]
}

private func lineupPlayerSort(_ first: RosterPlayer, _ second: RosterPlayer) -> Bool {
    positionSortWeight(first) < positionSortWeight(second)
}

private func positionSortWeight(_ player: RosterPlayer) -> Int {
    let label = normalizePositionLabel(player.position?.abbreviation, displayName: player.position?.displayName)
    if ["LB", "LWB", "LW", "LM", "LCB", "LCM"].contains(label) { return 0 }
    if ["RB", "RWB", "RW", "RM", "RCB", "RCM"].contains(label) { return 2 }
    return 1
}

func playerRating(_ player: RosterPlayer) -> String? {
    let ratingStat = player.stats?.first { stat in
        let name = stat.name?.lowercased() ?? ""
        let display = stat.displayName?.lowercased() ?? ""
        return name.contains("rating") || display.contains("rating")
    }
    return ratingStat?.displayValue
}

func ratingColor(_ rating: String?) -> Color {
    guard let value = Double(rating ?? "") else { return Color.white.opacity(0.18) }
    if value >= 8.0 { return Color(red: 0, green: 0.68, blue: 0.77) }
    if value >= 7.0 { return Color(red: 0, green: 0.77, blue: 0.14) }
    if value >= 6.5 { return Color(red: 0.85, green: 0.69, blue: 0) }
    if value >= 6.0 { return Color(red: 0.93, green: 0.49, blue: 0.03) }
    return .red
}

extension EventStatus {
    var isLive: Bool {
        type?.state == "in"
    }

    var statusPillText: String {
        if isLive {
            return displayClock ?? type?.shortDetail ?? "LIVE"
        }
        return type?.shortDetail ?? type?.description ?? "Scheduled"
    }
}

extension TeamRecord {
    var bestSummary: String? {
        summary ?? displayValue
    }
}

extension Color {
    init?(hex: String?) {
        guard var value = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        if value.hasPrefix("#") {
            value.removeFirst()
        }

        guard value.count == 6, let number = Int(value, radix: 16) else {
            return nil
        }

        let red = Double((number >> 16) & 0xff) / 255
        let green = Double((number >> 8) & 0xff) / 255
        let blue = Double(number & 0xff) / 255
        self.init(red: red, green: green, blue: blue)
    }

    static let pitchInk = Color(red: 0.01, green: 0.011, blue: 0.014)
}

extension Team {
    var lineupPrimaryColor: Color {
        Color(hex: color) ?? Color.white.opacity(0.28)
    }

    var lineupSecondaryColor: Color {
        Color(hex: alternateColor) ?? Color.white.opacity(0.2)
    }
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.015, green: 0.016, blue: 0.020),
                Color(red: 0.055, green: 0.058, blue: 0.066),
                Color.pitchInk
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
