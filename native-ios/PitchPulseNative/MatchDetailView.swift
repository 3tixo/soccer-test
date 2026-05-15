import SwiftUI

@MainActor
struct MatchDetailView: View {
    let event: ScoreEvent
    let league: League

    @State private var summary: MatchSummary?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var activeTab: MatchDetailTab = .summary
    @State private var selectedShotHome = true

    private let service = SofaScoreService()

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    scoreboard

                    if isLoading {
                        detailLoadingBlock
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
        .task(id: event.id) {
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
                        .font(.system(size: event.status?.type?.state == "pre" ? 23 : 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                    Text(event.status?.statusPillText ?? "Scheduled")
                        .font(.caption.weight(.black))
                        .foregroundStyle(event.status?.isLive == true ? .white : .secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, event.status?.isLive == true ? 8 : 0)
                        .frame(height: event.status?.isLive == true ? CGFloat(24) : nil)
                        .background {
                            if event.status?.isLive == true {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.red.opacity(0.92))
                            }
                        }
                }
                .frame(minWidth: 104)

                detailTeam(teams.away)
            }

            HStack(spacing: 8) {
                Label(shortDate(event.date), systemImage: "calendar")
                    .lineLimit(1)
                if let venue = event.competition?.venue?.fullName ?? event.competition?.venue?.displayName {
                    Label(venue, systemImage: "mappin.and.ellipse")
                        .lineLimit(1)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
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
            let sections = timelineSections
            if sections.isEmpty {
                StateCard(title: "No timeline yet", detail: "SofaScore has not published match events for this fixture.")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(section.title.uppercased())
                                .font(.caption2.weight(.black))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 5)
                            ForEach(Array(section.events.enumerated()), id: \.offset) { _, item in
                                TimelineRow(event: item)
                            }
                        }
                    }
                }
            }
        }
    }

    private var detailLoadingBlock: some View {
        DetailBlock(title: "Loading details") {
            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 42, height: 12)
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                                .frame(height: 12)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 160, height: 10)
                        }
                    }
                }
            }
            .redacted(reason: .placeholder)
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
                StateCard(title: "No odds", detail: "SofaScore did not return odds for this match.")
            }
        }
    }

    private var statsBlock: some View {
        DetailBlock(title: "Match stats") {
            let rows = matchStatRows
            if let shots = summary?.shotmap, !shots.isEmpty {
                ShotMapBoard(event: event, shots: shots, selectedHome: $selectedShotHome)
            }

            if rows.isEmpty && (summary?.shotmap ?? []).isEmpty {
                StateCard(title: "No stats yet", detail: "Stats appear when SofaScore publishes official match data.")
            } else if !rows.isEmpty {
                VStack(spacing: 12) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
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
                    ForEach(Array(articles.enumerated()), id: \.offset) { _, article in
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

    private var timelineSections: [TimelineSection] {
        let grouped = Dictionary(grouping: timelineEvents) { event -> String in
            let minute = event.clock?.value ?? event.time?.value ?? 0
            if minute <= 45 { return "First half" }
            if minute <= 90 { return "Second half" }
            return "Extra time"
        }

        return ["First half", "Second half", "Extra time"].compactMap { title in
            let events = grouped[title] ?? []
            return events.isEmpty ? nil : TimelineSection(title: title, events: events)
        }
    }

    private var matchStatRows: [MatchStatItem] {
        guard let teams = summary?.boxscore?.teams, teams.count >= 2 else {
            return []
        }

        guard let homeTeam = teams.first, let awayTeam = teams.dropFirst().first else {
            return []
        }

        let homeStats = statMap(homeTeam.statistics)
        let awayStats = statMap(awayTeam.statistics)
        let definitions: [(String, [String], String)] = [
            ("Expected goals", ["expectedGoals", "xg", "Expected goals"], ""),
            ("Possession", ["ballPossession", "Possession"], ""),
            ("Shots", ["totalShotsOnGoal", "totalShots", "Total shots"], ""),
            ("On target", ["shotsOnGoal", "Shots on target"], ""),
            ("Big chances", ["bigChanceCreated", "Big chances"], ""),
            ("Corners", ["cornerKicks", "Corner kicks"], ""),
            ("Fouls", ["fouls", "Fouls"], ""),
            ("Yellow cards", ["yellowCards", "Yellow cards"], ""),
            ("Red cards", ["redCards", "Red cards"], ""),
            ("Passes", ["passes", "Passes"], ""),
            ("Tackles", ["totalTackle", "Tackles"], "")
        ]

        return definitions.compactMap { label, names, suffix in
            guard let home = firstStat(homeStats, names: names), let away = firstStat(awayStats, names: names) else { return nil }
            return MatchStatItem(
                label: label,
                home: displayValue(home, suffix: suffix),
                away: displayValue(away, suffix: suffix),
                homeValue: home.numericValue,
                awayValue: away.numericValue
            )
        }
    }

    private func firstStat(_ stats: [String: GameStatistic], names: [String]) -> GameStatistic? {
        for name in names {
            if let stat = stats[name] {
                return stat
            }
            if let match = stats.first(where: { $0.key.caseInsensitiveCompare(name) == .orderedSame }) {
                return match.value
            }
        }
        return nil
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
        let leagueId = league.id
        let eventId = event.id
        let service = self.service

        isLoading = true
        errorMessage = nil

        do {
            let loadedSummary = try await service.fetchSummary(leagueId: leagueId, eventId: eventId)
            guard !Task.isCancelled else { return }
            summary = loadedSummary
        } catch ProviderError.providerBlocked {
            guard !Task.isCancelled else { return }
            errorMessage = "SofaScore blocked this client request. This may need a backend proxy."
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "SofaScore did not return summary data for this match."
        }

        guard !Task.isCancelled else { return }
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

struct TimelineSection {
    let title: String
    let events: [TimelineEvent]
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
    let label: String
    let home: String
    let away: String
    let homeValue: Double
    let awayValue: Double

    var id: String { label }
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

struct ShotMapBoard: View {
    let event: ScoreEvent
    let shots: [ShotMapItem]
    @Binding var selectedHome: Bool
    @State private var selectedShotId: String?

    private var teams: MatchTeams {
        event.matchTeams
    }

    private var homeShots: [ShotMapItem] {
        shots.filter { $0.isHome == true }
    }

    private var awayShots: [ShotMapItem] {
        shots.filter { $0.isHome == false }
    }

    private var displayShots: [ShotMapItem] {
        let sideShots = selectedHome ? homeShots : awayShots
        return sideShots.isEmpty ? shots : sideShots
    }

    private var selectedShot: ShotMapItem? {
        displayShots.first { $0.id == selectedShotId } ?? displayShots.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Shots")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.white)
                Spacer()
                teamSelector
            }

            shotPitch

            if let selectedShot {
                ShotDetailCard(shot: selectedShot)
            }
        }
        .onAppear {
            if homeShots.isEmpty && !awayShots.isEmpty {
                selectedHome = false
            }
            selectedShotId = selectedShot?.id
        }
        .onChange(of: selectedHome) { _ in
            selectedShotId = displayShots.first?.id
        }
    }

    private var teamSelector: some View {
        HStack(spacing: 4) {
            shotTeamButton(team: teams.home?.team, isHome: true, disabled: homeShots.isEmpty)
            shotTeamButton(team: teams.away?.team, isHome: false, disabled: awayShots.isEmpty)
        }
        .padding(3)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }

    private func shotTeamButton(team: Team?, isHome: Bool, disabled: Bool) -> some View {
        Button {
            selectedHome = isHome
        } label: {
            TeamBadge(team: team)
                .frame(width: 28, height: 28)
                .opacity(disabled ? 0.35 : 1)
                .padding(.horizontal, 8)
                .frame(height: 32)
                .background(selectedHome == isHome ? Color.white.opacity(0.92) : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var shotPitch: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fieldTop: CGFloat = 34
            let fieldHeight = proxy.size.height - fieldTop
            let selected = selectedShot

            ZStack(alignment: .top) {
                ShotGoalNet()
                    .frame(width: min(width * 0.32, 98), height: 34)
                    .position(x: width / 2, y: 17)

                ZStack {
                    ShotGrass()
                    ShotPitchLines()
                        .stroke(Color(red: 0.06, green: 0.13, blue: 0.08), lineWidth: 1.2)
                }
                .frame(width: width, height: fieldHeight)
                .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
                .position(x: width / 2, y: fieldTop + fieldHeight / 2)

                if let selected {
                    let start = point(for: selected, width: width, height: fieldHeight, offsetY: fieldTop)
                    let target = targetPoint(for: selected, width: width, offsetY: fieldTop)
                    Path { path in
                        path.move(to: start)
                        path.addLine(to: target)
                    }
                    .stroke(Color.white.opacity(0.86), style: StrokeStyle(lineWidth: 1.3, dash: [3, 4]))
                }

                ForEach(displayShots) { shot in
                    Button {
                        selectedShotId = shot.id
                    } label: {
                        ShotDot(shot: shot, selected: shot.id == selected?.id)
                    }
                    .buttonStyle(.plain)
                    .position(point(for: shot, width: width, height: fieldHeight, offsetY: fieldTop))
                }
            }
        }
        .frame(height: 292)
        .background(Color.black.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func point(for shot: ShotMapItem, width: CGFloat, height: CGFloat, offsetY: CGFloat) -> CGPoint {
        let rawX = clamp(shot.playerCoordinates?.x ?? 50)
        let rawY = clamp(shot.playerCoordinates?.y ?? 50)
        let leftValue = shot.isHome == false ? 100 - rawY : rawY
        let topValue = 100 - rawX
        return CGPoint(
            x: width * CGFloat(leftValue / 100),
            y: offsetY + height * CGFloat(topValue / 100)
        )
    }

    private func targetPoint(for shot: ShotMapItem, width: CGFloat, offsetY: CGFloat) -> CGPoint {
        let rawY = clamp(shot.goalMouthCoordinates?.y ?? 50)
        let leftValue = shot.isHome == false ? 100 - rawY : rawY
        return CGPoint(x: width * CGFloat(leftValue / 100), y: offsetY + 2)
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 4), 96)
    }
}

struct ShotGrass: View {
    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { index in
                    Rectangle()
                        .fill(index.isMultiple(of: 2) ? Color(red: 0.27, green: 0.43, blue: 0.28) : Color(red: 0.31, green: 0.49, blue: 0.32))
                        .frame(height: proxy.size.height / 5)
                }
            }
        }
    }
}

struct ShotPitchLines: Shape {
    func path(in rect: CGRect) -> Path {
        func x(_ value: CGFloat) -> CGFloat { rect.minX + rect.width * value / 100 }
        func y(_ value: CGFloat) -> CGFloat { rect.minY + rect.height * value / 100 }

        var path = Path()
        path.addRect(CGRect(x: x(5), y: y(8), width: rect.width * 0.90, height: rect.height * 0.82))
        path.move(to: CGPoint(x: x(50), y: y(8)))
        path.addLine(to: CGPoint(x: x(50), y: y(90)))
        path.addArc(center: CGPoint(x: x(50), y: y(90)), radius: rect.width * 0.12, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
        path.addRect(CGRect(x: x(24), y: y(8), width: rect.width * 0.52, height: rect.height * 0.28))
        path.addRect(CGRect(x: x(37), y: y(8), width: rect.width * 0.26, height: rect.height * 0.13))
        path.addArc(center: CGPoint(x: x(5), y: y(8)), radius: rect.width * 0.04, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addArc(center: CGPoint(x: x(95), y: y(8)), radius: rect.width * 0.04, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
        return path
    }
}

struct ShotGoalNet: View {
    var body: some View {
        ZStack {
            Rectangle()
                .stroke(Color.white.opacity(0.92), lineWidth: 3)
            GridPattern()
                .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                .padding(3)
        }
        .background(Color.black.opacity(0.36))
        .mask(
            Rectangle()
                .padding(.bottom, -6)
        )
    }
}

struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 1..<8 {
            let x = rect.minX + rect.width * CGFloat(index) / 8
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        for index in 1..<5 {
            let y = rect.minY + rect.height * CGFloat(index) / 5
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}

struct ShotDot: View {
    let shot: ShotMapItem
    let selected: Bool

    var body: some View {
        Circle()
            .fill(fillColor)
            .frame(width: selected ? 21 : 16, height: selected ? 21 : 16)
            .overlay(Circle().stroke(borderColor, lineWidth: selected ? 3 : 2))
            .shadow(color: borderColor.opacity(selected ? 0.45 : 0), radius: 4)
    }

    private var fillColor: Color {
        if isGoal { return .white }
        if (shot.shotType ?? "").lowercased().contains("save") { return Color(red: 0.85, green: 0.94, blue: 0.84) }
        return Color(red: 0.72, green: 0.86, blue: 0.70)
    }

    private var borderColor: Color {
        isGoal ? Color(red: 0.24, green: 0.78, blue: 0.32) : Color(red: 0.17, green: 0.40, blue: 0.20)
    }

    private var isGoal: Bool {
        (shot.shotType ?? "").lowercased().contains("goal")
    }
}

struct ShotDetailCard: View {
    let shot: ShotMapItem

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(clock)
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                Spacer()
                Text(shot.player?.bestName ?? "Shot")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                shotMetric("xG", value: formatted(shot.xg))
                shotMetric("xGOT", value: formatted(shot.xgot))
                shotMetric("Outcome", value: display(shot.shotType))
            }

            HStack(spacing: 8) {
                shotMetric("Situation", value: display(shot.situation))
                shotMetric("Shot type", value: display(shot.bodyPart))
                shotMetric("Goal zone", value: display(shot.goalMouthLocation))
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.36))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func shotMetric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var clock: String {
        guard let time = shot.time else { return "-" }
        if let added = shot.addedTime, added > 0 {
            return "\(time)' +\(added)"
        }
        return "\(time)'"
    }

    private func formatted(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.2f", value)
    }

    private func display(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "-" }
        return value
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
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
