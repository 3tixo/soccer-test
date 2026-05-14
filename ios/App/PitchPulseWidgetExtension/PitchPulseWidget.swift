import Foundation
import SwiftUI
import WidgetKit

struct MatchEntry: TimelineEntry {
    let date: Date
    let league: String
    let status: String
    let home: String
    let away: String
    let score: String
}

struct MatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> MatchEntry {
        MatchEntry(
            date: Date(),
            league: "Premier League",
            status: "Scheduled",
            home: "Home",
            away: "Away",
            score: "-:-"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MatchEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MatchEntry>) -> Void) {
        fetchMatchEntry { entry in
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
            completion(Timeline(entries: [entry], policy: .after(refreshDate)))
        }
    }

    private func fetchMatchEntry(completion: @escaping (MatchEntry) -> Void) {
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard") else {
            completion(fallbackEntry(status: "ESPN unavailable"))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard
                let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let events = json["events"] as? [[String: Any]],
                let event = pickBestEvent(events)
            else {
                completion(fallbackEntry(status: "No matches"))
                return
            }

            completion(entry(from: event))
        }.resume()
    }
}

private func pickBestEvent(_ events: [[String: Any]]) -> [String: Any]? {
    if let live = events.first(where: { statusState($0) == "in" }) {
        return live
    }
    if let upcoming = events.first(where: { statusState($0) == "pre" }) {
        return upcoming
    }
    return events.first
}

private func entry(from event: [String: Any]) -> MatchEntry {
    let competition = (event["competitions"] as? [[String: Any]])?.first
    let competitors = competition?["competitors"] as? [[String: Any]] ?? []
    let home = competitors.first(where: { $0["homeAway"] as? String == "home" }) ?? competitors.first ?? [:]
    let away = competitors.first(where: { $0["homeAway"] as? String == "away" }) ?? competitors.dropFirst().first ?? [:]
    let status = event["status"] as? [String: Any]
    let type = status?["type"] as? [String: Any]
    let state = type?["state"] as? String ?? ""
    let statusText = type?["shortDetail"] as? String ?? type?["description"] as? String ?? "Scheduled"
    let isPre = state == "pre"
    let homeName = teamName(home)
    let awayName = teamName(away)
    let score = isPre ? kickoffTime(event["date"] as? String) : "\(home["score"] as? String ?? "-")-\(away["score"] as? String ?? "-")"

    return MatchEntry(
        date: Date(),
        league: "Premier League",
        status: statusText,
        home: homeName,
        away: awayName,
        score: score
    )
}

private func fallbackEntry(status: String) -> MatchEntry {
    MatchEntry(
        date: Date(),
        league: "PitchPulse",
        status: status,
        home: "Open app",
        away: "for scores",
        score: "-:-"
    )
}

private func statusState(_ event: [String: Any]) -> String {
    let status = event["status"] as? [String: Any]
    let type = status?["type"] as? [String: Any]
    return type?["state"] as? String ?? ""
}

private func teamName(_ competitor: [String: Any]) -> String {
    let team = competitor["team"] as? [String: Any]
    return team?["shortDisplayName"] as? String
        ?? team?["displayName"] as? String
        ?? team?["name"] as? String
        ?? "TBA"
}

private func kickoffTime(_ isoDate: String?) -> String {
    guard let isoDate, let date = ISO8601DateFormatter().date(from: isoDate) else {
        return "TBA"
    }
    return date.formatted(date: .omitted, time: .shortened)
}

struct PitchPulseWidgetView: View {
    var entry: MatchEntry

    var body: some View {
        widgetContent
            .modifier(WidgetBackground())
    }

    private var widgetContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PitchPulse")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(Color(red: 0.18, green: 0.89, blue: 0.56))
                Spacer()
                Text(entry.status)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(entry.league.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.home)
                    .font(.headline.weight(.heavy))
                    .lineLimit(1)
                Text(entry.away)
                    .font(.headline.weight(.heavy))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(entry.score)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .minimumScaleFactor(0.7)
        }
        .padding(14)
        .foregroundStyle(.white)
    }
}

struct WidgetBackground: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(Color(red: 0.03, green: 0.08, blue: 0.06), for: .widget)
        } else {
            content.background(Color(red: 0.03, green: 0.08, blue: 0.06))
        }
    }
}

@main
struct PitchPulseWidget: Widget {
    let kind = "PitchPulseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MatchProvider()) { entry in
            PitchPulseWidgetView(entry: entry)
        }
        .configurationDisplayName("PitchPulse Match")
        .description("Shows a current or upcoming soccer match.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
