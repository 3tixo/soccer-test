import SwiftUI

struct TeamDetailView: View {
    let context: TeamDetailContext
    let league: League
    @ObservedObject var favoriteStore: FavoriteStore

    @State private var profileTeam: Team?
    @State private var scheduleEvents: [ScoreEvent] = []
    @State private var teamArticles: [NewsArticle] = []
    @State private var isLoadingDetails = true

    private let service = SofaScoreService()

    private var standingStats: [String: StandingStat] {
        Dictionary(uniqueKeysWithValues: (context.standing?.stats ?? []).compactMap { stat in
            guard let name = stat.name else { return nil }
            return (name, stat)
        })
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    hero
                    snapshot
                    if isLoadingDetails {
                        ProgressView()
                            .tint(Color.pitchAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    formBlock
                    scheduleBlock
                    newsBlock
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            await loadTeamDetails()
        }
    }

    private var hero: some View {
        HStack(spacing: 14) {
            TeamBadge(team: displayTeam)
                .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text(league.name.uppercased())
                    .font(.caption2.weight(.black))
                    .foregroundStyle(Color.pitchAccent)
                Text(displayTeam.bestName)
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(standingSummary)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                favoriteStore.toggle(displayTeam)
            } label: {
                Image(systemName: favoriteStore.contains(displayTeam) ? "star.fill" : "star")
                    .font(.headline.weight(.black))
                    .foregroundStyle(favoriteStore.contains(displayTeam) ? Color.pitchBackground : .white)
                    .frame(width: 42, height: 42)
                    .background(favoriteStore.contains(displayTeam) ? Color.pitchAccent : Color.pitchSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.pitchCard)
        .overlay(cardStroke(10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var snapshot: some View {
        DetailBlock(title: "Club") {
            HStack(spacing: 10) {
                clubTile(label: "Standing", value: standingSummary.isEmpty ? "-" : standingSummary)
                clubTile(label: "Record", value: recordSummary)
            }
        }
    }

    private func clubTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var formBlock: some View {
        DetailBlock(title: "Recent form") {
            let form = recentFormEvents
                .prefix(8)
                .map { result(for: $0) }

            if form.isEmpty {
                StateCard(title: "No form", detail: "SofaScore did not return completed fixtures for this club yet.")
            } else {
                HStack(spacing: 8) {
                    ForEach(Array(form.enumerated()), id: \.offset) { _, result in
                        Text(result)
                            .font(.caption.weight(.black))
                            .foregroundStyle(formColor(result))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    private var scheduleBlock: some View {
        DetailBlock(title: "Schedule") {
            if scheduleDisplayEvents.isEmpty {
                StateCard(title: "No matches", detail: "SofaScore did not return a team schedule.")
            } else {
                VStack(spacing: 8) {
                    ForEach(scheduleDisplayEvents.prefix(8)) { event in
                        scheduleRow(event)
                    }
                }
            }
        }
    }

    private var newsBlock: some View {
        DetailBlock(title: "Team news") {
            if loadedArticles.isEmpty {
                StateCard(title: "No team media", detail: "No loaded SofaScore media matched this club.")
            } else {
                VStack(spacing: 10) {
                    ForEach(loadedArticles.prefix(4)) { article in
                        NewsCard(article: article)
                    }
                }
            }
        }
    }

    private func scheduleRow(_ event: ScoreEvent) -> some View {
        let teams = event.matchTeams
        let opponent = teams.home?.team?.stableId == displayTeam.stableId ? teams.away : teams.home
        let prefix = teams.home?.team?.stableId == displayTeam.stableId ? "vs" : "@"
        let result = event.status?.type?.completed == true ? result(for: event) : kickoffTime(event.date)

        return HStack(spacing: 10) {
            Text(shortDate(event.date))
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            Text("\(prefix) \(opponent?.team?.bestName ?? "TBA")")
                .font(.subheadline.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Text(event.status?.isLive == true ? (event.status?.statusPillText ?? "LIVE") : result)
                .font(.caption.weight(.black))
                .foregroundStyle(event.status?.isLive == true ? .white : formColor(result))
                .padding(.horizontal, event.status?.isLive == true ? 8 : 0)
                .frame(height: event.status?.isLive == true ? CGFloat(24) : nil)
                .background {
                    if event.status?.isLive == true {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.red.opacity(0.92))
                    }
                }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var standingSummary: String {
        if let summary = displayTeam.standingSummary, !summary.isEmpty {
            return summary
        }
        guard let rank = statValue("rank"), !rank.isEmpty else { return "" }
        return "\(ordinal(rank)) in \(league.name)"
    }

    private var recordSummary: String {
        if let summary = displayTeam.recordSummary, !summary.isEmpty {
            return summary
        }
        let wins = statValue("wins") ?? "-"
        let ties = statValue("ties") ?? "-"
        let losses = statValue("losses") ?? "-"
        return "\(wins)-\(ties)-\(losses)"
    }

    private func statValue(_ name: String) -> String? {
        standingStats[name]?.displayValue ?? standingStats[name]?.summary ?? standingStats[name]?.value.map { String(Int($0)) }
    }

    private func result(for event: ScoreEvent) -> String {
        let competitors = event.competition?.competitors ?? []
        guard
            let team = competitors.first(where: { $0.team?.stableId == displayTeam.stableId }),
            let opponent = competitors.first(where: { $0.team?.stableId != displayTeam.stableId })
        else {
            return "-"
        }

        if team.winner == true { return "W" }
        if opponent.winner == true { return "L" }

        let teamScore = Int(team.score ?? "")
        let opponentScore = Int(opponent.score ?? "")
        if let teamScore, let opponentScore {
            if teamScore > opponentScore { return "W" }
            if teamScore < opponentScore { return "L" }
            return "D"
        }
        return "-"
    }

    private func formColor(_ result: String) -> Color {
        switch result {
        case "W": return Color.pitchAccent
        case "L": return .red
        case "D": return .yellow
        default: return .secondary
        }
    }

    private var displayTeam: Team {
        profileTeam ?? context.team
    }

    private var loadedEvents: [ScoreEvent] {
        scheduleEvents.isEmpty ? context.events : scheduleEvents
    }

    private var recentFormEvents: [ScoreEvent] {
        loadedEvents
            .filter { $0.status?.type?.completed == true }
            .sorted(by: newestFirst)
    }

    private var scheduleDisplayEvents: [ScoreEvent] {
        let upcoming = loadedEvents
            .filter { $0.status?.type?.completed != true }
            .sorted(by: oldestFirst)
        if !upcoming.isEmpty {
            return upcoming
        }
        return loadedEvents.sorted(by: newestFirst)
    }

    private var loadedArticles: [NewsArticle] {
        teamArticles.isEmpty ? context.articles : teamArticles
    }

    private func loadTeamDetails() async {
        guard let teamId = context.team.id else {
            isLoadingDetails = false
            return
        }

        isLoadingDetails = true
        async let profile: Team? = try? service.fetchTeamProfile(leagueId: league.id, teamId: teamId)
        async let schedule: [ScoreEvent]? = try? service.fetchTeamSchedule(leagueId: league.id, teamId: teamId)
        async let news: [NewsArticle]? = try? service.fetchTeamNews(leagueId: league.id, teamId: teamId)

        profileTeam = await profile ?? context.team
        scheduleEvents = await schedule ?? []
        teamArticles = await news ?? []
        isLoadingDetails = false
    }

    private func newestFirst(_ first: ScoreEvent, _ second: ScoreEvent) -> Bool {
        eventDate(first) > eventDate(second)
    }

    private func oldestFirst(_ first: ScoreEvent, _ second: ScoreEvent) -> Bool {
        eventDate(first) < eventDate(second)
    }

    private func eventDate(_ event: ScoreEvent) -> Date {
        guard let date = event.date, let parsed = ISO8601DateFormatter().date(from: date) else {
            return .distantPast
        }
        return parsed
    }
}
