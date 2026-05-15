import ActivityKit
import AppIntents
import Foundation
import SwiftUI
import UIKit
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
        case .premierLeague: return "17"
        case .laLiga: return "8"
        case .serieA: return "23"
        case .bundesliga: return "35"
        case .ligue1: return "34"
        case .championsLeague: return "7"
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
    case liveOnly
    case nextMatch
    case latestResult
    case teamNextMatch
    case teamLatestResult
    case teamLiveOnly

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Display")
    static var caseDisplayRepresentations: [WidgetDisplayOption: DisplayRepresentation] = [
        .liveFirst: "Live first",
        .liveOnly: "Live only",
        .nextMatch: "Next match",
        .latestResult: "Latest result",
        .teamNextMatch: "Team next match",
        .teamLatestResult: "Team latest result",
        .teamLiveOnly: "Team live only"
    ]

    var label: String {
        switch self {
        case .liveFirst: return "Live first"
        case .liveOnly: return "Live only"
        case .nextMatch: return "Next match"
        case .latestResult: return "Latest result"
        case .teamNextMatch: return "Team next"
        case .teamLatestResult: return "Team latest"
        case .teamLiveOnly: return "Team live"
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

    @Parameter(title: "Team Filter", default: "")
    var teamFilter: String
}

struct NativeWidgetEntry: TimelineEntry {
    let date: Date
    let league: String
    let mode: String
    let status: String
    let statusShort: String
    let detail: String
    let isLive: Bool
    let home: String
    let away: String
    let homeScore: String
    let awayScore: String
    let homeLogoData: Data?
    let awayLogoData: Data?
}

struct NativeWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NativeWidgetEntry {
        NativeWidgetEntry(
            date: Date(),
            league: "Premier League",
            mode: "Live first",
            status: "45'",
            statusShort: "45'",
            detail: "Live now",
            isLive: true,
            home: "Arsenal",
            away: "Chelsea",
            homeScore: "1",
            awayScore: "0",
            homeLogoData: nil,
            awayLogoData: nil
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
        let hasTeamFilter = !configuration.teamFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let offsets = widgetDateOffsets(for: configuration.display, hasTeamFilter: hasTeamFilter)
        var events: [[String: Any]] = []
        var seenIds = Set<String>()

        for offset in offsets {
            let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
            let fetchedEvents = (try? await fetchEvents(leagueId: configuration.league.leagueId, date: date)) ?? []
            for event in fetchedEvents {
                let id = eventIdentifier(event)
                guard !seenIds.contains(id) else { continue }
                seenIds.insert(id)
                events.append(event)
            }
        }

        guard let event = bestEvent(events, configuration: configuration) else {
            return fallback("No matching match", configuration: configuration)
        }

        return await entry(from: event, configuration: configuration)
    }

    private func fetchEvents(leagueId: String, date: Date) async throws -> [[String: Any]] {
        guard let url = URL(string: "https://api.sofascore.com/api/v1/unique-tournament/\(leagueId)/scheduled-events/\(apiDate(date))") else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("https://www.sofascore.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://www.sofascore.com", forHTTPHeaderField: "Origin")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return []
        }

        return json["events"] as? [[String: Any]] ?? []
    }
}

private func widgetDateOffsets(for display: WidgetDisplayOption, hasTeamFilter: Bool) -> [Int] {
    switch display {
    case .latestResult, .teamLatestResult:
        return Array((-21...0).reversed())
    case .liveOnly, .teamLiveOnly:
        return [-1, 0, 1]
    case .teamNextMatch:
        return Array(0...28)
    case .nextMatch:
        return hasTeamFilter ? Array(0...28) : Array(0...7)
    case .liveFirst:
        return hasTeamFilter ? Array(-1...28) : Array(-1...7)
    }
}

private func eventIdentifier(_ event: [String: Any]) -> String {
    if let id = event["id"] as? Int { return String(id) }
    if let id = event["id"] as? Int64 { return String(id) }
    if let id = event["id"] as? Double { return String(Int(id)) }
    if let id = event["id"] as? String { return id }
    return "\(teamName(event["homeTeam"] as? [String: Any] ?? [:]))-\(teamName(event["awayTeam"] as? [String: Any] ?? [:]))-\(timestampValue(event["startTimestamp"]) ?? 0)"
}

private func bestEvent(_ events: [[String: Any]], configuration: MatchWidgetIntent) -> [String: Any]? {
    let filteredEvents = teamFilteredEvents(events, query: configuration.teamFilter)
    let hasTeamFilter = !configuration.teamFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let source = hasTeamFilter ? filteredEvents : events

    switch configuration.display {
    case .liveFirst:
        return source.first { state($0) == "in" }
            ?? source.filter { state($0) == "pre" }.sorted(by: oldestEventFirst).first
            ?? source.filter { state($0) == "post" }.sorted(by: newestEventFirst).first
            ?? source.first
    case .liveOnly:
        return source.first { state($0) == "in" }
    case .nextMatch:
        return source.filter { state($0) == "pre" }.sorted(by: oldestEventFirst).first
            ?? source.first { state($0) == "in" }
            ?? source.first
    case .latestResult:
        return source.filter { state($0) == "post" }.sorted(by: newestEventFirst).first
            ?? source.first { state($0) == "in" }
            ?? source.first
    case .teamNextMatch:
        return source.filter { state($0) == "pre" }.sorted(by: oldestEventFirst).first
            ?? source.first { state($0) == "in" }
            ?? source.first
    case .teamLatestResult:
        return source.filter { state($0) == "post" }.sorted(by: newestEventFirst).first
            ?? source.first { state($0) == "in" }
            ?? source.first
    case .teamLiveOnly:
        return source.first { state($0) == "in" }
    }
}

private func teamFilteredEvents(_ events: [[String: Any]], query: String) -> [[String: Any]] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !needle.isEmpty else { return [] }
    return events.filter { event in
        let home = teamSearchText(event["homeTeam"] as? [String: Any] ?? [:])
        let away = teamSearchText(event["awayTeam"] as? [String: Any] ?? [:])
        return home.contains(needle) || away.contains(needle)
    }
}

private func entry(from event: [String: Any], configuration: MatchWidgetIntent) async -> NativeWidgetEntry {
    let home = event["homeTeam"] as? [String: Any] ?? [:]
    let away = event["awayTeam"] as? [String: Any] ?? [:]
    let isPre = state(event) == "pre"
    let live = state(event) == "in"
    let homeScore = isPre ? "-" : scoreText(event["homeScore"] as? [String: Any])
    let awayScore = isPre ? "-" : scoreText(event["awayScore"] as? [String: Any])
    let homeLogo = await logoData(for: home)
    let awayLogo = await logoData(for: away)

    return NativeWidgetEntry(
        date: Date(),
        league: configuration.league.displayName,
        mode: configuration.display.label,
        status: live ? liveClock(event) : statusText(event),
        statusShort: live ? liveClock(event) : compactStatusText(event),
        detail: matchDetail(event: event, homeScore: homeScore, awayScore: awayScore),
        isLive: live,
        home: teamName(home),
        away: teamName(away),
        homeScore: homeScore,
        awayScore: awayScore,
        homeLogoData: homeLogo,
        awayLogoData: awayLogo
    )
}

private func fallback(_ status: String, configuration: MatchWidgetIntent) -> NativeWidgetEntry {
    NativeWidgetEntry(
        date: Date(),
        league: configuration.league.displayName,
        mode: configuration.display.label,
        status: status,
        statusShort: status,
        detail: configuration.display.label,
        isLive: false,
        home: "Open PitchPulse",
        away: "to refresh scores",
        homeScore: "-",
        awayScore: "-",
        homeLogoData: nil,
        awayLogoData: nil
    )
}

private func state(_ event: [String: Any]) -> String {
    let status = event["status"] as? [String: Any]
    let type = status?["type"] as? String ?? ""
    if type == "inprogress" { return "in" }
    if type == "finished" { return "post" }
    return "pre"
}

private func statusText(_ event: [String: Any]) -> String {
    let status = event["status"] as? [String: Any]
    let type = status?["type"] as? String ?? ""
    if type == "finished" { return "FT" }
    return status?["description"] as? String ?? "Scheduled"
}

private func compactStatusText(_ event: [String: Any]) -> String {
    switch state(event) {
    case "post":
        return "FT"
    case "pre":
        return kickoffTime(timestampValue(event["startTimestamp"]))
    default:
        return statusText(event)
    }
}

private func liveClock(_ event: [String: Any]) -> String {
    let status = event["status"] as? [String: Any]
    return status?["description"] as? String ?? statusText(event)
}

private func teamName(_ team: [String: Any]) -> String {
    return team["shortName"] as? String
        ?? team["name"] as? String
        ?? "TBA"
}

private func teamSearchText(_ team: [String: Any]) -> String {
    [
        team["shortName"] as? String,
        team["name"] as? String,
        team["slug"] as? String,
        team["nameCode"] as? String
    ]
    .compactMap { $0 }
    .joined(separator: " ")
    .lowercased()
}

private func logoData(for team: [String: Any]) async -> Data? {
    guard let id = teamId(team),
          let url = URL(string: "https://img.sofascore.com/api/v1/team/\(id)/image")
    else {
        return nil
    }

    do {
        var request = URLRequest(url: url)
        request.setValue("image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    } catch {
        return nil
    }
}

private func teamId(_ team: [String: Any]) -> String? {
    if let id = team["id"] as? Int { return String(id) }
    if let id = team["id"] as? Int64 { return String(id) }
    if let id = team["id"] as? Double { return String(Int(id)) }
    return team["id"] as? String
}

private func scoreText(_ score: [String: Any]?) -> String {
    score?["display"] as? String
        ?? (score?["display"] as? Int).map { String($0) }
        ?? (score?["current"] as? Int).map { String($0) }
        ?? "-"
}

private func kickoffTime(_ timestamp: Int64?) -> String {
    guard let timestamp else { return "TBA" }
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    return date.formatted(date: .omitted, time: .shortened)
}

private func matchDetail(event: [String: Any], homeScore: String, awayScore: String) -> String {
    switch state(event) {
    case "in":
        return "Live now"
    case "post":
        if let home = Int(homeScore), let away = Int(awayScore) {
            if home == away { return "Full time - Draw" }
            return home > away ? "Full time - Home won" : "Full time - Away won"
        }
        return "Full time"
    default:
        return "Kickoff - \(kickoffTime(timestampValue(event["startTimestamp"])))"
    }
}

private func eventDate(_ event: [String: Any]) -> Date {
    guard let value = timestampValue(event["startTimestamp"]) else {
        return .distantPast
    }
    return Date(timeIntervalSince1970: TimeInterval(value))
}

private func timestampValue(_ value: Any?) -> Int64? {
    if let value = value as? Int64 { return value }
    if let value = value as? Int { return Int64(value) }
    if let value = value as? Double { return Int64(value) }
    if let value = value as? String { return Int64(value) }
    return nil
}

private func apiDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
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
        VStack(alignment: .leading, spacing: 10) {
            widgetHeader(compact: true)

            Spacer(minLength: 0)

            VStack(spacing: 9) {
                scoreRow(name: entry.home, score: entry.homeScore, logoData: entry.homeLogoData, nameSize: 17, scoreSize: 25, logoSize: 20)
                divider
                scoreRow(name: entry.away, score: entry.awayScore, logoData: entry.awayLogoData, nameSize: 17, scoreSize: 25, logoSize: 20)
            }

            Spacer(minLength: 0)

            Text(entry.detail)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetHeader(compact: false)

            VStack(spacing: 11) {
                scoreRow(name: entry.home, score: entry.homeScore, logoData: entry.homeLogoData, nameSize: 22, scoreSize: 31, logoSize: 26)
                divider
                scoreRow(name: entry.away, score: entry.awayScore, logoData: entry.awayLogoData, nameSize: 22, scoreSize: 31, logoSize: 26)
            }

            HStack(spacing: 6) {
                Text(entry.detail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 8)
                Text(entry.mode)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white.opacity(0.34))
                    .lineLimit(1)
            }
        }
        .padding(18)
    }

    private func widgetHeader(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(leagueCode)
                .font(.system(size: compact ? 14 : 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 6)

            statusBadge
        }
    }

    private func scoreRow(name: String, score: String, logoData: Data?, nameSize: CGFloat, scoreSize: CGFloat, logoSize: CGFloat) -> some View {
        HStack(spacing: 7) {
            TeamLogoMark(data: logoData, fallback: initials(name), size: logoSize)

            Text(name)
                .font(.system(size: nameSize, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            Spacer(minLength: 8)

            Text(score)
                .font(.system(size: scoreSize, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: scoreSize * 0.55, alignment: .trailing)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 1)
    }

    private var leagueCode: String {
        switch entry.league {
        case "Champions League": return "UCL"
        case "Premier League": return "EPL"
        case "LALIGA": return "LALIGA"
        case "Serie A": return "SERIE A"
        case "Bundesliga": return "BUND"
        case "Ligue 1": return "L1"
        default: return entry.league.uppercased()
        }
    }

    private func initials(_ value: String) -> String {
        let words = value.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        if letters.isEmpty {
            return String(value.prefix(2)).uppercased()
        }
        return String(letters).uppercased()
    }

    private var statusBadge: some View {
        Text(entry.statusShort)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(.white.opacity(entry.isLive ? 0.96 : 0.82))
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .padding(.horizontal, 8)
            .frame(height: CGFloat(23))
            .frame(maxWidth: CGFloat(82))
            .background {
                Capsule()
                    .fill(entry.isLive ? Color.red.opacity(0.92) : Color.white.opacity(0.10))
            }
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
    }
}

struct TeamLogoMark: View {
    let data: Data?
    let fallback: String
    let size: CGFloat

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(fallback)
                    .font(.system(size: size * 0.34, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
        }
        .frame(width: size, height: size)
    }

    private var image: UIImage? {
        guard let data else { return nil }
        return UIImage(data: data)
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

struct PitchPulseMatchWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "PitchPulseNativeWidget", intent: MatchWidgetIntent.self, provider: NativeWidgetProvider()) { entry in
            NativeWidgetView(entry: entry)
        }
        .configurationDisplayName("PitchPulse Match")
        .description("Choose a league and show live-first, next match, or latest result.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct PitchPulseLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatchLiveActivityAttributes.self) { context in
            LiveActivityLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveActivityTeamName(context.attributes.homeName, score: context.state.homeScore)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveActivityTeamName(context.attributes.awayName, score: context.state.awayScore)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.attributes.leagueName) - \(context.state.detail)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } compactLeading: {
                Text(context.state.homeScore)
                    .font(.caption.weight(.black))
            } compactTrailing: {
                Text(context.state.awayScore)
                    .font(.caption.weight(.black))
            } minimal: {
                Text(context.state.isLive ? "LIVE" : context.state.status)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(context.state.isLive ? .red : .white)
            }
            .keylineTint(context.state.isLive ? .red : .white.opacity(0.35))
        }
    }
}

struct LiveActivityLockScreenView: View {
    let context: ActivityViewContext<MatchLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(context.attributes.leagueName.uppercased())
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(context.state.status)
                    .font(.caption.weight(.black))
                    .foregroundStyle(context.state.isLive ? .white : .secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(context.state.isLive ? Color.red.opacity(0.90) : Color.white.opacity(0.10))
                    .clipShape(Capsule())
            }

            LiveActivityScoreRow(name: context.attributes.homeName, score: context.state.homeScore)
            LiveActivityScoreRow(name: context.attributes.awayName, score: context.state.awayScore)

            Text(context.state.detail)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(16)
        .activityBackgroundTint(Color(red: 0.02, green: 0.022, blue: 0.026))
        .activitySystemActionForegroundColor(.white)
    }
}

struct LiveActivityScoreRow: View {
    let name: String
    let score: String

    var body: some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Spacer(minLength: 8)
            Text(score)
                .font(.title2.weight(.black))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }
}

struct LiveActivityTeamName: View {
    let name: String
    let score: String

    init(_ name: String, score: String) {
        self.name = name
        self.score = score
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(score)
                .font(.title3.weight(.black))
                .monospacedDigit()
        }
    }
}

@main
struct PitchPulseNativeWidgetBundle: WidgetBundle {
    var body: some Widget {
        PitchPulseMatchWidget()
        PitchPulseLiveActivityWidget()
    }
}
