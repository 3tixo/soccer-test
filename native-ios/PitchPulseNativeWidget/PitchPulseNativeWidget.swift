import AppIntents
import Foundation
import SwiftUI
import WidgetKit

enum WidgetLeagueOption: String, AppEnum {
    case premierLeague
    case laLiga
    case serieA
    case bundesliga
    case ligue1
    case championsLeague

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "League")
    static var caseDisplayRepresentations: [WidgetLeagueOption: DisplayRepresentation] = [
        .premierLeague: "Premier League",
        .laLiga: "LALIGA",
        .serieA: "Serie A",
        .bundesliga: "Bundesliga",
        .ligue1: "Ligue 1",
        .championsLeague: "Champions League"
    ]

    var leagueId: String {
        switch self {
        case .premierLeague: return "eng.1"
        case .laLiga: return "esp.1"
        case .serieA: return "ita.1"
        case .bundesliga: return "ger.1"
        case .ligue1: return "fra.1"
        case .championsLeague: return "uefa.champions"
        }
    }

    var displayName: String {
        switch self {
        case .premierLeague: return "Premier League"
        case .laLiga: return "LALIGA"
        case .serieA: return "Serie A"
        case .bundesliga: return "Bundesliga"
        case .ligue1: return "Ligue 1"
        case .championsLeague: return "Champions League"
        }
    }
}

enum WidgetDisplayOption: String, AppEnum {
    case liveFirst
    case nextMatch
    case latestResult

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Display")
    static var caseDisplayRepresentations: [WidgetDisplayOption: DisplayRepresentation] = [
        .liveFirst: "Live first",
        .nextMatch: "Next match",
        .latestResult: "Latest result"
    ]

    var label: String {
        switch self {
        case .liveFirst: return "Live first"
        case .nextMatch: return "Next match"
        case .latestResult: return "Latest result"
        }
    }
}

struct MatchWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "PitchPulse Match"
    static var description = IntentDescription("Choose the league and match type shown on the widget.")

    @Parameter(title: "League", default: .premierLeague)
    var league: WidgetLeagueOption

    @Parameter(title: "Display", default: .liveFirst)
    var display: WidgetDisplayOption
}

struct NativeWidgetEntry: TimelineEntry {
    let date: Date
    let league: String
    let mode: String
    let status: String
    let isLive: Bool
    let home: String
    let away: String
    let score: String
}

struct NativeWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NativeWidgetEntry {
        NativeWidgetEntry(
            date: Date(),
            league: "Premier League",
            mode: "Live first",
            status: "45'",
            isLive: true,
            home: "Arsenal",
            away: "Chelsea",
            score: "1-0"
        )
    }

    func snapshot(for configuration: MatchWidgetIntent, in context: Context) async -> NativeWidgetEntry {
        await fetchEntry(configuration: configuration)
    }

    func timeline(for configuration: MatchWidgetIntent, in context: Context) async -> Timeline<NativeWidgetEntry> {
        let entry = await fetchEntry(configuration: configuration)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: entry.isLive ? 5 : 15, to: Date()) ?? Date().addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func fetchEntry(configuration: MatchWidgetIntent) async -> NativeWidgetEntry {
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/soccer/\(configuration.league.leagueId)/scoreboard") else {
            return fallback("ESPN unavailable", configuration: configuration)
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let events = json["events"] as? [[String: Any]],
                  let event = bestEvent(events, mode: configuration.display)
            else {
                return fallback("No matches", configuration: configuration)
            }

            return entry(from: event, configuration: configuration)
        } catch {
            return fallback("ESPN unavailable", configuration: configuration)
        }
    }
}

private func bestEvent(_ events: [[String: Any]], mode: WidgetDisplayOption) -> [String: Any]? {
    switch mode {
    case .liveFirst:
        return events.first { state($0) == "in" }
            ?? events.filter { state($0) == "pre" }.sorted(by: oldestEventFirst).first
            ?? events.filter { state($0) == "post" }.sorted(by: newestEventFirst).first
            ?? events.first
    case .nextMatch:
        return events.filter { state($0) == "pre" }.sorted(by: oldestEventFirst).first
            ?? events.first { state($0) == "in" }
            ?? events.first
    case .latestResult:
        return events.filter { state($0) == "post" }.sorted(by: newestEventFirst).first
            ?? events.first { state($0) == "in" }
            ?? events.first
    }
}

private func entry(from event: [String: Any], configuration: MatchWidgetIntent) -> NativeWidgetEntry {
    let competition = (event["competitions"] as? [[String: Any]])?.first
    let competitors = competition?["competitors"] as? [[String: Any]] ?? []
    let home = competitors.first { $0["homeAway"] as? String == "home" } ?? competitors.first ?? [:]
    let away = competitors.first { $0["homeAway"] as? String == "away" } ?? competitors.dropFirst().first ?? [:]
    let isPre = state(event) == "pre"
    let live = state(event) == "in"
    let score = isPre ? kickoffTime(event["date"] as? String) : "\(scoreText(home))-\(scoreText(away))"

    return NativeWidgetEntry(
        date: Date(),
        league: configuration.league.displayName,
        mode: configuration.display.label,
        status: live ? liveClock(event) : statusText(event),
        isLive: live,
        home: teamName(home),
        away: teamName(away),
        score: score
    )
}

private func fallback(_ status: String, configuration: MatchWidgetIntent) -> NativeWidgetEntry {
    NativeWidgetEntry(
        date: Date(),
        league: configuration.league.displayName,
        mode: configuration.display.label,
        status: status,
        isLive: false,
        home: "Open PitchPulse",
        away: "to refresh scores",
        score: "-:-"
    )
}

private func state(_ event: [String: Any]) -> String {
    let status = event["status"] as? [String: Any]
    let type = status?["type"] as? [String: Any]
    return type?["state"] as? String ?? ""
}

private func statusText(_ event: [String: Any]) -> String {
    let status = event["status"] as? [String: Any]
    let type = status?["type"] as? [String: Any]
    return type?["shortDetail"] as? String ?? type?["description"] as? String ?? "Scheduled"
}

private func liveClock(_ event: [String: Any]) -> String {
    let status = event["status"] as? [String: Any]
    return status?["displayClock"] as? String ?? statusText(event)
}

private func teamName(_ competitor: [String: Any]) -> String {
    let team = competitor["team"] as? [String: Any]
    return team?["shortDisplayName"] as? String
        ?? team?["displayName"] as? String
        ?? team?["name"] as? String
        ?? "TBA"
}

private func scoreText(_ competitor: [String: Any]) -> String {
    if let score = competitor["score"] as? String {
        return score
    }
    if let score = competitor["score"] as? [String: Any] {
        return score["displayValue"] as? String
            ?? (score["value"] as? Double).map { String(Int($0)) }
            ?? "-"
    }
    return "-"
}

private func kickoffTime(_ isoDate: String?) -> String {
    guard let isoDate, let date = ISO8601DateFormatter().date(from: isoDate) else { return "TBA" }
    return date.formatted(date: .omitted, time: .shortened)
}

private func eventDate(_ event: [String: Any]) -> Date {
    guard let value = event["date"] as? String, let date = ISO8601DateFormatter().date(from: value) else {
        return .distantPast
    }
    return date
}

private func oldestEventFirst(_ first: [String: Any], _ second: [String: Any]) -> Bool {
    eventDate(first) < eventDate(second)
}

private func newestEventFirst(_ first: [String: Any], _ second: [String: Any]) -> Bool {
    eventDate(first) > eventDate(second)
}

struct NativeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NativeWidgetEntry

    var body: some View {
        Group {
            if family == .systemMedium {
                mediumLayout
            } else {
                smallLayout
            }
        }
        .foregroundStyle(.white)
        .modifier(WidgetBackground())
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text("PULSE")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white.opacity(0.66))
                Spacer(minLength: 4)
                statusBadge
            }

            Text(entry.league.uppercased())
                .font(.caption2.weight(.black))
                .foregroundStyle(.white.opacity(0.48))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(entry.score)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 3) {
                teamText(entry.home, size: 14)
                teamText(entry.away, size: 14)
            }
        }
        .padding(13)
    }

    private var mediumLayout: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("PitchPulse")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white.opacity(0.72))
                    statusBadge
                }

                Text(entry.league.uppercased())
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(entry.mode)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 5) {
                    teamText(entry.home, size: 17)
                    teamText(entry.away, size: 17)
                }
            }

            Spacer(minLength: 4)

            Text(entry.score)
                .font(.system(size: 38, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(minWidth: 82, alignment: .trailing)
        }
        .padding(14)
    }

    private func teamText(_ value: String, size: CGFloat) -> some View {
        Text(value)
            .font(.system(size: size, weight: .black, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.58)
    }

    private var statusBadge: some View {
        Text(entry.status)
            .font(.caption2.weight(.black))
            .foregroundStyle(entry.isLive ? .white : .white.opacity(0.56))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, entry.isLive ? 7 : 6)
            .frame(height: CGFloat(20))
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(entry.isLive ? Color.red.opacity(0.92) : Color.white.opacity(0.08))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            }
    }
}

struct WidgetBackground: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(
                LinearGradient(
                    colors: [
                        Color(red: 0.015, green: 0.016, blue: 0.020),
                        Color(red: 0.075, green: 0.078, blue: 0.086)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                for: .widget
            )
        } else {
            content.background(Color(red: 0.015, green: 0.016, blue: 0.020))
        }
    }
}

@main
struct PitchPulseNativeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "PitchPulseNativeWidget", intent: MatchWidgetIntent.self, provider: NativeWidgetProvider()) { entry in
            NativeWidgetView(entry: entry)
        }
        .configurationDisplayName("PitchPulse Match")
        .description("Choose a league and show live-first, next match, or latest result.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
