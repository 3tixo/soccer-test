import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ScoreboardViewModel()
    @StateObject private var alertManager = MatchAlertManager()
    @State private var selectedEvent: ScoreEvent?
    @State private var selectedTeam: TeamDetailContext?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pitchBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        searchField
                        leagueStrip
                        dateControls
                        hero
                        tabPicker
                        activeSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .task {
                await viewModel.load()
                alertManager.refresh(events: viewModel.events, league: viewModel.selectedLeague)
            }
            .refreshable {
                await viewModel.load()
                alertManager.refresh(events: viewModel.events, league: viewModel.selectedLeague)
            }
            .sheet(item: $selectedEvent) { event in
                MatchDetailView(event: event, league: viewModel.selectedLeague)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedTeam) { context in
                TeamDetailView(context: context, league: viewModel.selectedLeague)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("SOCCER LIVE CENTER")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(Color.pitchAccent)
                Text("PitchPulse")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                Task {
                    await alertManager.toggle(events: viewModel.events, league: viewModel.selectedLeague)
                }
            } label: {
                Image(systemName: alertManager.isEnabled ? "bell.fill" : "bell")
                    .font(.headline.weight(.black))
                    .foregroundStyle(alertManager.isEnabled ? Color.pitchBackground : .white)
                    .frame(width: 44, height: 44)
                    .background(alertManager.isEnabled ? Color.pitchAccent : Color.pitchSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            if viewModel.isLoading {
                ProgressView()
                    .tint(Color.pitchAccent)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 14)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
            TextField("Search teams, matches, news", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(Color.pitchSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var leagueStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(nativeLeagues) { league in
                    Button {
                        Task {
                            await viewModel.select(league)
                            alertManager.refresh(events: viewModel.events, league: viewModel.selectedLeague)
                        }
                    } label: {
                        Text(league.name)
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(viewModel.selectedLeague == league ? Color.pitchBackground : .white)
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                            .background(viewModel.selectedLeague == league ? Color.pitchAccent : Color.pitchSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var dateControls: some View {
        HStack(spacing: 8) {
            Button {
                Task {
                    await viewModel.shiftDate(by: -1)
                    alertManager.refresh(events: viewModel.events, league: viewModel.selectedLeague)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.black))
                    .frame(width: 44, height: 44)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.isToday ? "Today" : "Match day")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.secondary)
                Text(viewModel.dateLabel)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.pitchSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button {
                Task {
                    await viewModel.goToToday()
                    alertManager.refresh(events: viewModel.events, league: viewModel.selectedLeague)
                }
            } label: {
                Text("Today")
                    .font(.caption.weight(.black))
                    .frame(height: 44)
                    .padding(.horizontal, 12)
            }
            .disabled(viewModel.isToday)
            .opacity(viewModel.isToday ? 0.5 : 1)

            Button {
                Task {
                    await viewModel.shiftDate(by: 1)
                    alertManager.refresh(events: viewModel.events, league: viewModel.selectedLeague)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.black))
                    .frame(width: 44, height: 44)
            }
        }
        .buttonStyle(DateButtonStyle())
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.selectedLeague.country.uppercased())
                .font(.caption.weight(.black))
                .foregroundStyle(.secondary)
            Text(viewModel.selectedLeague.name)
                .font(.title2.weight(.black))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                stat(label: "Matches", value: "\(viewModel.events.count)")
                stat(label: "Live", value: "\(viewModel.events.filter { $0.status?.type?.state == "in" }.count)")
                stat(label: "Teams", value: "\(viewModel.standings.count)")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pitchCard)
        .overlay(cardStroke(10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(10)
        .frame(minWidth: 78, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var tabPicker: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    viewModel.activeTab = tab
                } label: {
                    Label(tab.rawValue, systemImage: icon(for: tab))
                        .font(.caption.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundStyle(viewModel.activeTab == tab ? Color.pitchBackground : .secondary)
                        .background(viewModel.activeTab == tab ? .white : Color.pitchSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var activeSection: some View {
        switch viewModel.activeTab {
        case .matches:
            matchSection
        case .table:
            standingsSection
        case .news:
            newsSection
        }
    }

    private var matchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(kicker: "Fixtures", title: "\(viewModel.selectedLeague.name) Matches")

            if let errorMessage = viewModel.errorMessage, viewModel.events.isEmpty {
                StateCard(title: "ESPN error", detail: errorMessage)
            } else if viewModel.filteredEvents.isEmpty && !viewModel.isLoading {
                StateCard(title: "No matches", detail: "ESPN did not return matching fixtures.")
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.filteredEvents) { event in
                        Button {
                            selectedEvent = event
                        } label: {
                            MatchCard(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var standingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(kicker: "Table", title: "\(viewModel.selectedLeague.name) Standings")

            if viewModel.filteredStandings.isEmpty && !viewModel.isLoading {
                StateCard(title: "No table available", detail: "ESPN does not expose standings for every competition.")
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.filteredStandings.enumerated()), id: \.element.id) { index, entry in
                        Button {
                            selectedTeam = viewModel.teamContext(for: entry.team)
                        } label: {
                            StandingRow(entry: entry, fallbackRank: index + 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.pitchSurface)
                .overlay(cardStroke(10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var newsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(kicker: "Stories", title: "\(viewModel.selectedLeague.name) News")

            if viewModel.filteredArticles.isEmpty && !viewModel.isLoading {
                StateCard(title: "No news available", detail: "ESPN did not return matching articles.")
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.filteredArticles.prefix(12)) { article in
                        NewsCard(article: article)
                    }
                }
            }
        }
    }

    private func icon(for tab: AppTab) -> String {
        switch tab {
        case .matches: return "rectangle.grid.1x2"
        case .table: return "tablecells"
        case .news: return "newspaper"
        }
    }
}

struct SectionTitle: View {
    let kicker: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kicker.uppercased())
                .font(.caption2.weight(.black))
                .foregroundStyle(Color.pitchAccent)
            Text(title)
                .font(.title3.weight(.black))
                .foregroundStyle(.white)
        }
    }
}

struct MatchCard: View {
    let event: ScoreEvent

    private var teams: MatchTeams {
        event.matchTeams
    }

    private var isPre: Bool {
        event.status?.type?.state == "pre"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("MATCH")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(event.status?.type?.shortDetail ?? event.status?.type?.description ?? "Scheduled")
                    .font(.caption.weight(.black))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }

            teamLine(teams.home)
            teamLine(teams.away)

            if let venue = event.competition?.venue?.fullName ?? event.competition?.venue?.displayName {
                Label(venue, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(Color.pitchSurface)
        .overlay(cardStroke(10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var statusColor: Color {
        if event.status?.type?.state == "in" { return Color.pitchAccent }
        if event.status?.type?.completed == true { return .secondary }
        return .white
    }

    private func teamLine(_ competitor: Competitor?) -> some View {
        HStack(spacing: 10) {
            TeamBadge(team: competitor?.team)

            VStack(alignment: .leading, spacing: 2) {
                Text(competitor?.team?.bestName ?? "TBA")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(competitor?.records?.first?.summary ?? competitor?.team?.abbreviation ?? "")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(isPre ? competitor?.team?.abbreviation ?? "-" : competitor?.score ?? "-")
                .font(.title3.weight(.black))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }
}

struct TeamBadge: View {
    let team: Team?

    var body: some View {
        AsyncImage(url: URL(string: team?.bestLogo ?? "")) { image in
            image
                .resizable()
                .scaledToFit()
        } placeholder: {
            Circle()
                .fill(Color.white.opacity(0.08))
                .overlay(Text(team?.abbreviation ?? "-").font(.caption2.weight(.black)))
        }
        .frame(width: 34, height: 34)
    }
}

struct StandingRow: View {
    let entry: StandingEntry
    let fallbackRank: Int

    private var stats: [String: StandingStat] {
        Dictionary(uniqueKeysWithValues: (entry.stats ?? []).compactMap { stat in
            guard let name = stat.name else { return nil }
            return (name, stat)
        })
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(value("rank", fallback: "\(fallbackRank)"))
                .font(.subheadline.weight(.black))
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .leading)

            TeamBadge(team: entry.team)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.team?.bestName ?? "Team")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(recordText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(value("points", fallback: "-"))
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                Text("PTS")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
        }
    }

    private var recordText: String {
        let played = value("gamesPlayed", fallback: "-")
        let wins = value("wins", fallback: "-")
        let ties = value("ties", fallback: "-")
        let losses = value("losses", fallback: "-")
        let diff = value("pointDifferential", fallback: "-")
        return "GP \(played)  \(wins)-\(ties)-\(losses)  GD \(diff)"
    }

    private func value(_ name: String, fallback: String) -> String {
        stats[name]?.displayValue ?? stats[name]?.summary ?? stats[name]?.value.map { String(Int($0)) } ?? fallback
    }
}

struct NewsCard: View {
    let article: NewsArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let url = URL(string: article.images?.first?.url ?? "") {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.white.opacity(0.06))
                }
                .frame(height: 138)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Text(article.headline ?? "ESPN story")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(2)

            if let description = article.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pitchSurface)
        .overlay(cardStroke(10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct StateCard: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pitchSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct DateButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(configuration.isPressed ? Color.pitchCard : Color.pitchSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

func cardStroke(_ radius: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: radius, style: .continuous)
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
}

extension Color {
    static let pitchBackground = Color(red: 0.03, green: 0.08, blue: 0.06)
    static let pitchSurface = Color(red: 0.07, green: 0.15, blue: 0.11)
    static let pitchCard = Color(red: 0.04, green: 0.18, blue: 0.14)
    static let pitchAccent = Color(red: 0.18, green: 0.89, blue: 0.56)
}
