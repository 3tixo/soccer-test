import Foundation
import SwiftUI
import WidgetKit

struct NativeWidgetEntry: TimelineEntry {
    let date: Date
    let league: String
    let status: String
    let home: String
    let away: String
    let score: String
}

struct NativeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> NativeWidgetEntry {
        NativeWidgetEntry(date: Date(), league: "PitchPulse", status: "Loading", home: "Home", away: "Away", score: "-:-")
    }

    func getSnapshot(in context: Context, completion: @escaping (NativeWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NativeWidgetEntry>) -> Void) {
        fetchEntry { entry in
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
            completion(Timeline(entries: [entry], policy: .after(refreshDate)))
        }
    }

    private func fetchEntry(completion: @escaping (NativeWidgetEntry) -> Void) {
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard") else {
            completion(fallback("ESPN unavailable"))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard
                let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let events = json["events"] as? [[String: Any]],
                let event = bestEvent(events)
            else {
                completion(fallback("No matches"))
                return
            }

            completion(entry(from: event))
        }.resume()
    }
}

private func bestEvent(_ events: [[String: Any]]) -> [String: Any]? {
    events.first { state($0) == "in" } ?? events.first { state($0) == "pre" } ?? events.first
}

private func entry(from event: [String: Any]) -> NativeWidgetEntry {
    let competition = (event["competitions"] as? [[String: Any]])?.first
    let competitors = competition?["competitors"] as? [[String: Any]] ?? []
    let home = competitors.first { $0["homeAway"] as? String == "home" } ?? competitors.first ?? [:]
    let away = competitors.first { $0["homeAway"] as? String == "away" } ?? competitors.dropFirst().first ?? [:]
    let isPre = state(event) == "pre"
    let status = statusText(event)
    let score = isPre ? kickoffTime(event["date"] as? String) : "\(home["score"] as? String ?? "-")-\(away["score"] as? String ?? "-")"

    return NativeWidgetEntry(
        date: Date(),
        league: "Premier League",
        status: status,
        home: teamName(home),
        away: teamName(away),
        score: score
    )
}

private func fallback(_ status: String) -> NativeWidgetEntry {
    NativeWidgetEntry(date: Date(), league: "PitchPulse", status: status, home: "Open app", away: "for scores", score: "-:-")
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

private func teamName(_ competitor: [String: Any]) -> String {
    let team = competitor["team"] as? [String: Any]
    return team?["shortDisplayName"] as? String
        ?? team?["displayName"] as? String
        ?? team?["name"] as? String
        ?? "TBA"
}

private func kickoffTime(_ isoDate: String?) -> String {
    guard let isoDate, let date = ISO8601DateFormatter().date(from: isoDate) else { return "TBA" }
    return date.formatted(date: .omitted, time: .shortened)
}

struct NativeWidgetView: View {
    let entry: NativeWidgetEntry

    var body: some View {
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
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)

            Text(entry.home)
                .font(.headline.weight(.black))
                .lineLimit(1)
            Text(entry.away)
                .font(.headline.weight(.black))
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(entry.score)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .monospacedDigit()
        }
        .padding(14)
        .foregroundStyle(.white)
        .modifier(WidgetBackground())
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
struct PitchPulseNativeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PitchPulseNativeWidget", provider: NativeWidgetProvider()) { entry in
            NativeWidgetView(entry: entry)
        }
        .configurationDisplayName("PitchPulse Match")
        .description("Shows a current or upcoming soccer match.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
