import SwiftUI

struct MatchDetailView: View {
    let event: ScoreEvent
    let league: League

    @State private var summary: MatchSummary?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var activeTab: MatchDetailTab = .summary

    private let service = ESPNService()

    var body: some View {
        ZStack {
            Color.pitchBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    scoreboard

                    if isLoading {
                        ProgressView()
                            .tint(Color.pitchAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }

                    if let errorMessage {
                        StateCard(title: "Details unavailable", detail: errorMessage)
                    }

                    detailTabs
                    activeDetailSection
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            await loadSummary()
        }
    }

    private var scoreboard: some View {
        let teams = event.matchTeams

        return VStack(spacing: 14) {
            Text(league.name.uppercased())
                .font(.caption.weight(.black))
                .foregroundStyle(Color.pitchAccent)

            HStack(alignment: .center, spacing: 12) {
                detailTeam(teams.home)

                VStack(spacing: 4) {
                    Text(scoreText)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(event.status?.type?.shortDetail ?? event.status?.type?.description ?? "Scheduled")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(minWidth: 86)

                detailTeam(teams.away)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.pitchCard)
        .overlay(cardStroke(10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func detailTeam(_ competitor: Competitor?) -> some View {
        VStack(spacing: 8) {
            TeamBadge(team: competitor?.team)
                .frame(width: 48, height: 48)
            Text(competitor?.team?.bestName ?? "TBA")
                .font(.subheadline.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var scoreText: String {
        let teams = event.matchTeams
        if event.status?.type?.state == "pre" {
            return kickoffTime(event.date)
        }
        return "\(teams.home?.score ?? "-")-\(teams.away?.score ?? "-")"
    }

    private var timelineBlock: some View {
        DetailBlock(title: "Timeline") {
            let events = timelineEvents
            if events.isEmpty {
                StateCard(title: "No timeline yet", detail: "ESPN has not published match events for this fixture.")
            } else {
                VStack(spacing: 0) {
                    ForEach(events, id: \.stableId) { item in
                        TimelineRow(event: item)
                    }
                }
            }
        }
    }

    private var detailTabs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(MatchDetailTab.allCases) { tab in
                    Button {
                        activeTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.caption.weight(.black))
                            .foregroundStyle(activeTab == tab ? Color.pitchBackground : .white)
                            .padding(.horizontal, 12)
                            .frame(height: 38)
                            .background(activeTab == tab ? Color.pitchAccent : Color.pitchSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var activeDetailSection: some View {
        switch activeTab {
        case .summary:
            timelineBlock
        case .stats:
            statsBlock
        case .lineups:
            lineupsBlock
        case .odds:
            oddsBlock
        case .news:
            newsBlock
        }
    }

    private var oddsBlock: some View {
        let odds = pickedOdds
        return DetailBlock(title: "Odds") {
            if let odds, odds.hasDisplayableMoneyline {
                OddsBoard(odds: odds, event: event)
            } else {
                StateCard(title: "No odds", detail: "ESPN did not return odds for this match.")
            }
        }
    }

    private var statsBlock: some View {
        DetailBlock(title: "Match stats") {
            let rows = matchStatRows
            if rows.isEmpty {
                StateCard(title: "No stats yet", detail: "Stats appear when ESPN publishes official match data.")
            } else {
                VStack(spacing: 12) {
                    ForEach(rows) { row in
                        MatchStatRow(row: row)
                    }
                }
            }
        }
    }

    private var lineupsBlock: some View {
        DetailBlock(title: "Lineups") {
            LineupView(groups: summary?.rosters ?? [])
        }
    }

    private var newsBlock: some View {
        let articles = Array((summary?.news?.articles ?? []).prefix(3))
        return DetailBlock(title: "Match news") {
            if articles.isEmpty {
                EmptyView()
            } else {
                VStack(spacing: 10) {
                    ForEach(articles) { article in
                        NewsCard(article: article)
                    }
                }
            }
        }
    }

    private var timelineEvents: [TimelineEvent] {
        if let keyEvents = summary?.keyEvents, !keyEvents.isEmpty {
            return keyEvents.sortedByClock
        }

        let importantTypes: Set<String> = [
            "goal",
            "goal---free-kick",
            "goal---header",
            "goal---penalty",
            "goal---own-goal",
            "penalty---scored",
            "yellow-card",
            "red-card",
            "second-yellow-card",
            "substitution",
            "deleted-after-review",
            "var---referee-decision-cancelled",
            "var---goal-awarded",
            "var---penalty-awarded",
            "var---penalty-not-awarded",
            "kickoff",
            "halftime",
            "start-2nd-half",
            "end-regular-time"
        ]

        return (summary?.commentary ?? [])
            .compactMap(\.play)
            .filter { importantTypes.contains($0.type?.type ?? "") }
            .sortedByClock
    }

    private var matchStatRows: [MatchStatItem] {
        guard let teams = summary?.boxscore?.teams, teams.count >= 2 else {
            return []
        }

        let homeStats = statMap(teams[0].statistics)
        let awayStats = statMap(teams[1].statistics)
        let definitions = [
            ("Possession", "possessionPct", "%"),
            ("Shots", "totalShots", ""),
            ("On target", "shotsOnTarget", ""),
            ("Corners", "wonCorners", ""),
            ("Fouls", "foulsCommitted", ""),
            ("Yellow cards", "yellowCards", ""),
            ("Red cards", "redCards", "")
        ]

        return definitions.compactMap { label, name, suffix in
            guard let home = homeStats[name], let away = awayStats[name] else { return nil }
            return MatchStatItem(
                label: label,
                home: displayValue(home, suffix: suffix),
                away: displayValue(away, suffix: suffix),
                homeValue: home.numericValue,
                awayValue: away.numericValue
            )
        }
    }

    private var pickedOdds: OddsItem? {
        let items = (summary?.odds ?? []).filter(\.hasDisplayableMoneyline)
        let named: (String) -> OddsItem? = { needle in
            items.first { item in
                item.providerName.lowercased().contains(needle)
            }
        }

        return named("bet 365")
            ?? named("bet365")
            ?? items.first { !$0.providerName.lowercased().contains("draftkings") }
            ?? items.first
    }

    private func loadSummary() async {
        isLoading = true
        errorMessage = nil

        do {
            summary = try await service.fetchSummary(leagueId: league.id, eventId: event.id)
        } catch {
            errorMessage = "ESPN did not return summary data for this match."
        }

        isLoading = false
    }
}

enum MatchDetailTab: String, CaseIterable, Identifiable {
    case summary = "Summary"
    case stats = "Stats"
    case lineups = "Lineups"
    case odds = "Odds"
    case news = "News"

    var id: String { rawValue }
}

struct DetailBlock<Content: View>: View {
    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pitchSurface)
        .overlay(cardStroke(10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct TimelineRow: View {
    let event: TimelineEvent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(event.clock?.displayValue ?? event.time?.displayValue ?? "")
                .font(.caption.weight(.black))
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)

            Image(systemName: icon)
                .font(.subheadline.weight(.black))
                .foregroundStyle(color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.shortText ?? event.type?.text ?? "Match event")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.white)
                if let text = event.text, text != event.shortText {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let team = event.team?.bestName {
                    Text(team)
                        .font(.caption2.weight(.black))
                        .foregroundStyle(Color.pitchAccent)
                }
            }
        }
        .padding(.vertical, 9)
    }

    private var icon: String {
        let type = event.type?.type ?? ""
        if type.contains("goal") || type.contains("penalty---scored") { return "soccerball" }
        if type.contains("red-card") { return "rectangle.fill" }
        if type.contains("yellow-card") { return "rectangle.fill" }
        if type.contains("substitution") { return "arrow.triangle.2.circlepath" }
        if type.contains("var") { return "video" }
        return "circle.fill"
    }

    private var color: Color {
        let type = event.type?.type ?? ""
        if type.contains("red-card") { return .red }
        if type.contains("yellow-card") { return .yellow }
        if type.contains("goal") { return Color.pitchAccent }
        return .secondary
    }
}

struct MatchStatItem: Identifiable {
    let id = UUID()
    let label: String
    let home: String
    let away: String
    let homeValue: Double
    let awayValue: Double
}

struct MatchStatRow: View {
    let row: MatchStatItem

    private var homeRatio: Double {
        let total = row.homeValue + row.awayValue
        guard total > 0 else { return 0.5 }
        return row.homeValue / total
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(row.home)
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)
                Spacer()
                Text(row.label)
                    .font(.caption.weight(.black))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(row.away)
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Color.pitchAccent)
                        .frame(width: proxy.size.width * homeRatio)
                }
            }
            .frame(height: 5)
        }
    }
}

struct OddsBoard: View {
    let odds: OddsItem
    let event: ScoreEvent

    private var teams: MatchTeams {
        event.matchTeams
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(odds.providerName)
                    .font(.caption.weight(.black))
                    .foregroundStyle(.secondary)
                Spacer()
                if odds.providerName.lowercased().contains("bet365") || odds.providerName.lowercased().contains("bet 365") {
                    Text("bet365")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Color.pitchAccent)
                }
            }

            HStack(spacing: 8) {
                oddsCell(label: teams.home?.team?.abbreviation ?? "Home", value: odds.homeDecimal)
                oddsCell(label: "Draw", value: odds.drawDecimal)
                oddsCell(label: teams.away?.team?.abbreviation ?? "Away", value: odds.awayDecimal)
            }

            if let details = odds.details, !details.isEmpty {
                Text(details)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private func oddsCell(label: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value.isEmpty ? "-" : value)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension OddsItem {
    var providerName: String {
        provider?.name ?? header?.text ?? "Odds"
    }

    var homeDecimal: String {
        firstDecimal([
            moneyline?.home?.close?.odds,
            homeTeamOdds?.moneyLine,
            homeTeamOdds?.odds?.summary
        ])
    }

    var awayDecimal: String {
        firstDecimal([
            moneyline?.away?.close?.odds,
            awayTeamOdds?.moneyLine,
            awayTeamOdds?.odds?.summary
        ])
    }

    var drawDecimal: String {
        firstDecimal([
            moneyline?.draw?.close?.odds,
            drawOdds?.moneyLine,
            drawOdds?.summary
        ])
    }

    var hasDisplayableMoneyline: Bool {
        !homeDecimal.isEmpty || !awayDecimal.isEmpty || !drawDecimal.isEmpty
    }

    private func firstDecimal(_ values: [FlexibleOddsValue?]) -> String {
        values
            .map(decimalOdds)
            .first { !$0.isEmpty } ?? ""
    }
}
