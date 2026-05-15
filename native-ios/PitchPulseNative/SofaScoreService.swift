import Combine
import Foundation

enum ProviderError: Error {
    case invalidURL
    case badResponse(Int)
    case providerBlocked
}

struct SofaScoreService {
    private let apiBase = "https://api.sofascore.com/api/v1"
    private let imageBase = "https://img.sofascore.com/api/v1"

    func fetchScoreboard(leagueId: String, date: Date, useProviderDefaultDate: Bool) async throws -> ScoreboardResponse {
        let response: SofaEventsResponse = try await fetch("/unique-tournament/\(leagueId)/scheduled-events/\(Self.apiDate(date))")
        return ScoreboardResponse(
            day: ScoreboardDay(date: Self.apiDate(date)),
            events: response.events?.map(mapEvent) ?? []
        )
    }

    func fetchStandings(leagueId: String) async throws -> [StandingEntry] {
        let seasonId = try await currentSeasonId(for: leagueId)
        let response: SofaStandingsResponse = try await fetch("/unique-tournament/\(leagueId)/season/\(seasonId)/standings/total")
        return response.standings?.flatMap { standing in
            standing.rows?.map(mapStandingRow) ?? []
        } ?? []
    }

    func fetchNews(leagueId: String) async throws -> [NewsArticle] {
        if let response: SofaMediaResponse = try? await fetch("/unique-tournament/\(leagueId)/media") {
            return response.media?.map(mapMedia) ?? []
        }

        let posts: [SofaNewsPost] = try await fetch("/sofascore-news/en/posts?page=1&per_page=12&categories=football")
        return posts.map(mapPost)
    }

    func fetchSummary(leagueId: String, eventId: String) async throws -> MatchSummary {
        let loadedEventDetail: SofaEventResponse? = await optionalFetch("/event/\(eventId)")
        let loadedIncidents: SofaIncidentsResponse? = await optionalFetch("/event/\(eventId)/incidents")
        let loadedStatistics: SofaStatisticsResponse? = await optionalFetch("/event/\(eventId)/statistics")
        let loadedLineups: SofaLineupsResponse? = await optionalFetch("/event/\(eventId)/lineups")
        let loadedNews: SofaEventNewsResponse? = await optionalFetch("/event/\(eventId)/media/news")
        let loadedOdds: SofaFeaturedOddsResponse? = await optionalFetch("/event/\(eventId)/odds/1/featured")

        return MatchSummary(
            keyEvents: mapIncidents(loadedIncidents?.incidents ?? []),
            commentary: nil,
            boxscore: mapStatistics(loadedStatistics),
            news: NewsResponse(articles: loadedNews?.newsArticles?.map(mapEventNews) ?? []),
            odds: mapFeaturedOdds(loadedOdds),
            rosters: mapLineups(loadedLineups, event: loadedEventDetail?.event)
        )
    }

    func fetchTeamProfile(leagueId: String, teamId: String) async throws -> Team? {
        let response: SofaTeamResponse = try await fetch("/team/\(teamId)")
        return response.team.map(mapTeam)
    }

    func fetchTeamSchedule(leagueId: String, teamId: String) async throws -> [ScoreEvent] {
        let previous: SofaEventsResponse? = await optionalFetch("/team/\(teamId)/events/last/0")
        let next: SofaEventsResponse? = await optionalFetch("/team/\(teamId)/events/next/0")
        let events = (previous?.events ?? []) + (next?.events ?? [])
        return events.map(mapEvent)
    }

    func fetchTeamNews(leagueId: String, teamId: String) async throws -> [NewsArticle] {
        let response: SofaMediaResponse = try await fetch("/team/\(teamId)/media")
        return response.media?.map(mapMedia) ?? []
    }

    private func currentSeasonId(for leagueId: String) async throws -> Int {
        let response: SofaSeasonsResponse = try await fetch("/unique-tournament/\(leagueId)/seasons")
        guard let id = response.seasons?.first?.id else {
            throw ProviderError.badResponse(200)
        }
        return id
    }

    private func fetch<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(apiBase)\(path)") else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("https://www.sofascore.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://www.sofascore.com", forHTTPHeaderField: "Origin")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.badResponse(0)
        }
        if httpResponse.statusCode == 403 {
            throw ProviderError.providerBlocked
        }
        guard httpResponse.statusCode == 200 else {
            throw ProviderError.badResponse(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func optionalFetch<T: Decodable>(_ path: String) async -> T? {
        try? await fetch(path)
    }

    static func apiDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func dateFromAPIDay(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func mapEvent(_ event: SofaEvent) -> ScoreEvent {
        let homeTeam = event.homeTeam.map(mapTeam)
        let awayTeam = event.awayTeam.map(mapTeam)
        let homeScore = scoreText(event.homeScore)
        let awayScore = scoreText(event.awayScore)
        let home = Competitor(
            id: event.homeTeam.map { String($0.id) },
            homeAway: "home",
            score: homeScore,
            winner: event.winnerCode == 1,
            team: homeTeam,
            records: nil
        )
        let away = Competitor(
            id: event.awayTeam.map { String($0.id) },
            homeAway: "away",
            score: awayScore,
            winner: event.winnerCode == 2,
            team: awayTeam,
            records: nil
        )
        let name = "\(homeTeam?.bestName ?? "TBA") vs \(awayTeam?.bestName ?? "TBA")"
        let shortName = "\(homeTeam?.abbreviation ?? homeTeam?.bestName ?? "TBA") - \(awayTeam?.abbreviation ?? awayTeam?.bestName ?? "TBA")"

        return ScoreEvent(
            id: String(event.id),
            name: name,
            shortName: shortName,
            date: isoString(from: event.startTimestamp),
            status: mapStatus(event.status),
            competitions: [Competition(competitors: [home, away], venue: event.venue.map(mapVenue))]
        )
    }

    private func mapTeam(_ team: SofaTeam) -> Team {
        let id = String(team.id)
        return Team(
            id: id,
            displayName: team.name,
            shortDisplayName: team.shortName,
            name: team.name,
            abbreviation: team.nameCode,
            logo: "\(imageBase)/team/\(id)/image",
            logos: nil,
            color: team.teamColors?.primary,
            alternateColor: team.teamColors?.secondary,
            recordSummary: nil,
            standingSummary: nil
        )
    }

    private func mapStandingRow(_ row: SofaStandingRow) -> StandingEntry {
        let record = "\(row.wins ?? 0)-\(row.draws ?? 0)-\(row.losses ?? 0)"
        let stats = [
            standingStat("rank", row.position),
            standingStat("gamesPlayed", row.matches),
            standingStat("wins", row.wins),
            standingStat("ties", row.draws),
            standingStat("losses", row.losses),
            standingStat("points", row.points),
            StandingStat(
                name: "pointDifferential",
                displayName: "Goal Difference",
                displayValue: row.scoreDiffFormatted,
                summary: row.scoreDiffFormatted,
                value: Double(row.scoreDiffFormatted?.replacingOccurrences(of: "+", with: "") ?? "")
            )
        ]

        var team = row.team.map(mapTeam)
        if let existingTeam = team {
            team = Team(
                id: existingTeam.id,
                displayName: existingTeam.displayName,
                shortDisplayName: existingTeam.shortDisplayName,
                name: existingTeam.name,
                abbreviation: existingTeam.abbreviation,
                logo: existingTeam.logo,
                logos: existingTeam.logos,
                color: existingTeam.color,
                alternateColor: existingTeam.alternateColor,
                recordSummary: record,
                standingSummary: row.position.map { "\(ordinal(String($0))) in table" }
            )
        }

        return StandingEntry(team: team, stats: stats, note: row.promotion.map { StandingNote(description: $0.text, color: nil) })
    }

    private func standingStat(_ name: String, _ value: Int?) -> StandingStat {
        StandingStat(
            name: name,
            displayName: name,
            displayValue: value.map { String($0) },
            summary: value.map { String($0) },
            value: value.map { Double($0) }
        )
    }

    private func mapStatus(_ status: SofaStatus?) -> EventStatus {
        let type = status?.type ?? ""
        let mappedState: String
        let completed: Bool
        let shortDetail: String

        switch type {
        case "inprogress":
            mappedState = "in"
            completed = false
            shortDetail = status?.description ?? "Live"
        case "finished":
            mappedState = "post"
            completed = true
            shortDetail = "FT"
        case "notstarted":
            mappedState = "pre"
            completed = false
            shortDetail = "Scheduled"
        default:
            mappedState = completedStatusTypes.contains(type) ? "post" : "pre"
            completed = completedStatusTypes.contains(type)
            shortDetail = status?.description ?? "Scheduled"
        }

        return EventStatus(
            displayClock: type == "inprogress" ? status?.description : nil,
            type: StatusType(state: mappedState, completed: completed, description: status?.description, shortDetail: shortDetail)
        )
    }

    private var completedStatusTypes: Set<String> {
        ["finished", "afterpenalties", "afterextra", "canceled", "postponed"]
    }

    private func mapVenue(_ venue: SofaVenue) -> Venue {
        Venue(fullName: venue.stadium?.name ?? venue.name, displayName: venue.name)
    }

    private func mapStatistics(_ response: SofaStatisticsResponse?) -> Boxscore? {
        guard let period = response?.statistics?.first(where: { $0.period == "ALL" }) ?? response?.statistics?.first else {
            return nil
        }

        var homeStats: [GameStatistic] = []
        var awayStats: [GameStatistic] = []
        for group in period.groups ?? [] {
            for item in group.statisticsItems ?? [] {
                let key = item.key ?? item.name
                homeStats.append(GameStatistic(name: key, displayName: item.name, shortDisplayName: item.name, displayValue: item.home, value: item.homeValue))
                awayStats.append(GameStatistic(name: key, displayName: item.name, shortDisplayName: item.name, displayValue: item.away, value: item.awayValue))
            }
        }

        return Boxscore(teams: [
            BoxscoreTeam(team: nil, statistics: homeStats),
            BoxscoreTeam(team: nil, statistics: awayStats)
        ])
    }

    private func mapIncidents(_ incidents: [SofaIncident]) -> [TimelineEvent] {
        incidents.compactMap { incident in
            guard let type = incident.incidentType else { return nil }
            let playerName = incident.player?.shortName ?? incident.player?.name
            let text = incidentText(incident)
            return TimelineEvent(
                id: incident.id.map { String($0) } ?? "\(type)-\(incident.time ?? 0)-\(playerName ?? "")",
                text: text,
                shortText: text,
                type: TimelineType(type: type, text: type.capitalized),
                clock: TimelineClock(displayValue: clockText(incident), value: Double(incident.time ?? 0)),
                time: nil,
                team: nil
            )
        }
    }

    private func incidentText(_ incident: SofaIncident) -> String {
        switch incident.incidentType {
        case "goal":
            let scorer = incident.player?.shortName ?? incident.player?.name ?? "Goal"
            if let assist = incident.assist1?.shortName ?? incident.assist1?.name {
                return "\(scorer), assist \(assist)"
            }
            return scorer
        case "card":
            let card = incident.incidentClass?.capitalized ?? "Card"
            let player = incident.player?.shortName ?? incident.player?.name ?? "Player"
            return "\(card) card: \(player)"
        case "substitution":
            let playerIn = incident.playerIn?.shortName ?? incident.playerIn?.name ?? "In"
            let playerOut = incident.playerOut?.shortName ?? incident.playerOut?.name ?? "Out"
            return "\(playerIn) for \(playerOut)"
        case "period":
            return incident.text ?? "Period"
        default:
            return incident.text ?? incident.incidentType?.capitalized ?? "Match event"
        }
    }

    private func clockText(_ incident: SofaIncident) -> String {
        guard let minute = incident.time else { return "" }
        if let added = incident.addedTime, added > 0, added < 100 {
            return "\(minute)+\(added)'"
        }
        return "\(minute)'"
    }

    private func mapLineups(_ response: SofaLineupsResponse?, event: SofaEvent?) -> [RosterGroup]? {
        guard let response else { return nil }
        let homeTeam = event?.homeTeam.map(mapTeam)
        let awayTeam = event?.awayTeam.map(mapTeam)
        let home = response.home.map { side in
            RosterGroup(team: homeTeam, homeAway: "home", formation: side.formation, roster: mapLineupPlayers(side.players))
        }
        let away = response.away.map { side in
            RosterGroup(team: awayTeam, homeAway: "away", formation: side.formation, roster: mapLineupPlayers(side.players))
        }
        return [home, away].compactMap { $0 }
    }

    private func mapLineupPlayers(_ players: [SofaLineupPlayer]?) -> [RosterPlayer] {
        (players ?? []).map { player in
            RosterPlayer(
                athlete: Athlete(
                    id: player.player.flatMap { sofaPlayer in
                        sofaPlayer.id.map { String($0) }
                    },
                    displayName: player.player?.name,
                    shortName: player.player?.shortName,
                    headshot: nil
                ),
                jersey: player.jerseyNumber ?? player.shirtNumber.map { String($0) },
                starter: player.substitute == true ? false : true,
                position: PlayerPosition(abbreviation: player.position ?? player.player?.position, displayName: player.position ?? player.player?.position),
                formationPlace: player.formationPosition,
                subbedIn: nil,
                subbedOut: nil,
                stats: player.statistics?.rating.map { [GameStatistic(name: "rating", displayName: "Rating", shortDisplayName: "Rating", displayValue: String(format: "%.1f", $0), value: $0)] }
            )
        }
    }

    private func mapFeaturedOdds(_ response: SofaFeaturedOddsResponse?) -> [OddsItem]? {
        guard let choices = response?.featured?.fullTime?.choices ?? response?.featured?.defaultMarket?.choices, choices.count >= 3 else {
            return nil
        }
        let home = choices.first { $0.name == "1" }?.fractionalValue
        let draw = choices.first { $0.name == "X" }?.fractionalValue
        let away = choices.first { $0.name == "2" }?.fractionalValue

        return [
            OddsItem(
                provider: OddsProvider(name: "SofaScore odds"),
                header: nil,
                details: response?.featured?.fullTime?.marketName ?? "Full time",
                overUnder: nil,
                homeTeamOdds: TeamOdds(moneyLine: home.map(FlexibleOddsValue.text), odds: nil),
                awayTeamOdds: TeamOdds(moneyLine: away.map(FlexibleOddsValue.text), odds: nil),
                drawOdds: DrawOdds(moneyLine: draw.map(FlexibleOddsValue.text), summary: nil),
                moneyline: nil
            )
        ]
    }

    private func mapMedia(_ media: SofaMediaItem) -> NewsArticle {
        NewsArticle(
            headline: media.title,
            description: media.subtitle,
            images: media.thumbnailUrl.map { [ArticleImage(url: $0)] },
            links: media.url.map { ArticleLinks(web: ArticleLink(href: $0)) },
            published: media.createdAtTimestamp.flatMap { isoString(from: $0) }
        )
    }

    private func mapPost(_ post: SofaNewsPost) -> NewsArticle {
        NewsArticle(
            headline: post.title,
            description: post.excerpt,
            images: post.image.map { [ArticleImage(url: $0)] },
            links: post.link.map { ArticleLinks(web: ArticleLink(href: $0)) },
            published: post.date
        )
    }

    private func mapEventNews(_ article: SofaEventNewsArticle) -> NewsArticle {
        NewsArticle(
            headline: article.header,
            description: article.description,
            images: article.thumbnailUrl.map { [ArticleImage(url: $0)] },
            links: article.externalUrl.map { ArticleLinks(web: ArticleLink(href: $0)) },
            published: article.publishedAtTimestamp.flatMap { isoString(from: $0) }
        )
    }

    private func scoreText(_ score: SofaScore?) -> String? {
        if let display = score?.display { return String(display) }
        if let current = score?.current { return String(current) }
        return nil
    }

    private func isoString(from timestamp: Int64?) -> String? {
        guard let timestamp else { return nil }
        return ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }
}

@MainActor
final class ScoreboardViewModel: ObservableObject {
    @Published var selectedLeague = nativeLeagues[0]
    @Published var selectedDate = Date()
    @Published var hasUserPickedDate = false
    @Published var activeTab: AppTab = .matches
    @Published var searchText = ""
    @Published var events: [ScoreEvent] = []
    @Published var standings: [StandingEntry] = []
    @Published var articles: [NewsArticle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = SofaScoreService()
    private var loadGeneration = 0

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var dateLabel: String {
        selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    var filteredEvents: [ScoreEvent] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return events }
        return events.filter { $0.searchText.contains(query) }
    }

    var filteredStandings: [StandingEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return standings }
        return standings.filter { entry in
            entry.team?.bestName.lowercased().contains(query) == true
                || entry.team?.abbreviation?.lowercased().contains(query) == true
        }
    }

    var filteredArticles: [NewsArticle] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return articles }
        return articles.filter { article in
            "\(article.headline ?? "") \(article.description ?? "")".lowercased().contains(query)
        }
    }

    func select(_ league: League) async {
        selectedLeague = league
        hasUserPickedDate = false
        searchText = ""
        await load(useProviderDefaultDate: true, preserveExisting: false)
    }

    func shiftDate(by days: Int) async {
        selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
        hasUserPickedDate = true
        await load(useProviderDefaultDate: false, preserveExisting: false)
    }

    func goToToday() async {
        selectedDate = Date()
        hasUserPickedDate = true
        await load(useProviderDefaultDate: false, preserveExisting: false)
    }

    func teamContext(for team: Team?) -> TeamDetailContext? {
        guard let team else { return nil }
        let teamId = team.id
        let teamName = team.bestName.lowercased()
        let standing = standings.first { entry in
            entry.team?.id == teamId || entry.team?.bestName.lowercased() == teamName
        }
        let teamEvents = events.filter { event in
            (event.competition?.competitors ?? []).contains { competitor in
                competitor.team?.id == teamId || competitor.team?.bestName.lowercased() == teamName
            }
        }
        let teamArticles = articles.filter { article in
            "\(article.headline ?? "") \(article.description ?? "")".lowercased().contains(teamName)
        }
        return TeamDetailContext(team: team, standing: standing, events: teamEvents, articles: teamArticles)
    }

    func load(useProviderDefaultDate: Bool? = nil, preserveExisting: Bool = true) async {
        loadGeneration += 1
        let generation = loadGeneration
        let league = selectedLeague
        let date = selectedDate
        let service = self.service
        isLoading = true
        defer {
            if generation == loadGeneration {
                isLoading = false
            }
        }
        errorMessage = nil
        let shouldUseDefaultDate = useProviderDefaultDate ?? !hasUserPickedDate

        let scoreboardOutcome: Result<ScoreboardResponse, Error> = await captureProviderResult {
            try await service.fetchScoreboard(
                leagueId: league.id,
                date: date,
                useProviderDefaultDate: shouldUseDefaultDate
            )
        }
        let standingsOutcome: Result<[StandingEntry], Error> = await captureProviderResult {
            try await service.fetchStandings(leagueId: league.id)
        }
        let newsOutcome: Result<[NewsArticle], Error> = await captureProviderResult {
            try await service.fetchNews(leagueId: league.id)
        }

        guard generation == loadGeneration else { return }

        var primaryError: Error?

        switch scoreboardOutcome {
        case .success(let scoreboard):
            events = scoreboard.events ?? []
            if shouldUseDefaultDate, let providerDate = SofaScoreService.dateFromAPIDay(scoreboard.day?.date) {
                selectedDate = providerDate
            }
        case .failure(let error):
            primaryError = error
            if !preserveExisting {
                events = []
            }
        }

        switch standingsOutcome {
        case .success(let loadedStandings):
            standings = loadedStandings
        case .failure:
            if !preserveExisting {
                standings = []
            }
        }

        switch newsOutcome {
        case .success(let loadedArticles):
            articles = loadedArticles
        case .failure:
            if !preserveExisting {
                articles = []
            }
        }

        if let primaryError, events.isEmpty {
            if isProviderBlocked(primaryError) {
                errorMessage = "SofaScore blocked this client request. The private API may need a backend proxy."
            } else {
                errorMessage = "Could not load SofaScore matches."
            }
        } else {
            errorMessage = nil
        }

    }
}

private func captureProviderResult<T>(_ operation: () async throws -> T) async -> Result<T, Error> {
    do {
        return .success(try await operation())
    } catch {
        return .failure(error)
    }
}

private func isProviderBlocked(_ error: Error) -> Bool {
    if case ProviderError.providerBlocked = error {
        return true
    }
    return false
}

extension ScoreEvent {
    var searchText: String {
        let competitors = competition?.competitors ?? []
        let teams = competitors.map { $0.team?.bestName ?? "" }.joined(separator: " ")
        return "\(name ?? "") \(shortName ?? "") \(teams)".lowercased()
    }
}

private struct SofaEventsResponse: Decodable {
    let events: [SofaEvent]?
}

private struct SofaEventResponse: Decodable {
    let event: SofaEvent?
}

private struct SofaEvent: Decodable {
    let id: Int64
    let slug: String?
    let startTimestamp: Int64?
    let status: SofaStatus?
    let homeTeam: SofaTeam?
    let awayTeam: SofaTeam?
    let homeScore: SofaScore?
    let awayScore: SofaScore?
    let winnerCode: Int?
    let tournament: SofaTournament?
    let season: SofaSeason?
    let venue: SofaVenue?
}

private struct SofaStatus: Decodable {
    let code: Int?
    let description: String?
    let type: String?
}

private struct SofaScore: Decodable {
    let current: Int?
    let display: Int?
    let normaltime: Int?
}

private struct SofaTeam: Decodable {
    let id: Int
    let name: String?
    let shortName: String?
    let nameCode: String?
    let teamColors: SofaTeamColors?
}

private struct SofaTeamColors: Decodable {
    let primary: String?
    let secondary: String?
    let text: String?
}

private struct SofaTournament: Decodable {
    let name: String?
    let uniqueTournament: SofaUniqueTournament?
}

private struct SofaUniqueTournament: Decodable {
    let id: Int?
    let name: String?
}

private struct SofaSeason: Decodable {
    let id: Int?
    let name: String?
    let year: String?
}

private struct SofaVenue: Decodable {
    let name: String?
    let stadium: SofaStadium?
}

private struct SofaStadium: Decodable {
    let name: String?
}

private struct SofaSeasonsResponse: Decodable {
    let seasons: [SofaSeason]?
}

private struct SofaStandingsResponse: Decodable {
    let standings: [SofaStanding]?
}

private struct SofaStanding: Decodable {
    let rows: [SofaStandingRow]?
}

private struct SofaStandingRow: Decodable {
    let team: SofaTeam?
    let position: Int?
    let matches: Int?
    let wins: Int?
    let draws: Int?
    let losses: Int?
    let points: Int?
    let scoreDiffFormatted: String?
    let promotion: SofaPromotion?
}

private struct SofaPromotion: Decodable {
    let text: String?
}

private struct SofaTeamResponse: Decodable {
    let team: SofaTeam?
}

private struct SofaStatisticsResponse: Decodable {
    let statistics: [SofaStatisticsPeriod]?
}

private struct SofaStatisticsPeriod: Decodable {
    let period: String?
    let groups: [SofaStatisticsGroup]?
}

private struct SofaStatisticsGroup: Decodable {
    let groupName: String?
    let statisticsItems: [SofaStatisticsItem]?
}

private struct SofaStatisticsItem: Decodable {
    let name: String?
    let home: String?
    let away: String?
    let homeValue: Double?
    let awayValue: Double?
    let key: String?
}

private struct SofaIncidentsResponse: Decodable {
    let incidents: [SofaIncident]?
}

private struct SofaIncident: Decodable {
    let id: Int64?
    let text: String?
    let time: Int?
    let addedTime: Int?
    let incidentType: String?
    let incidentClass: String?
    let player: SofaPlayer?
    let assist1: SofaPlayer?
    let playerIn: SofaPlayer?
    let playerOut: SofaPlayer?
}

private struct SofaLineupsResponse: Decodable {
    let confirmed: Bool?
    let home: SofaLineupSide?
    let away: SofaLineupSide?
}

private struct SofaLineupSide: Decodable {
    let players: [SofaLineupPlayer]?
    let formation: String?
}

private struct SofaLineupPlayer: Decodable {
    let player: SofaPlayer?
    let shirtNumber: Int?
    let jerseyNumber: String?
    let position: String?
    let substitute: Bool?
    let formationPosition: Int?
    let statistics: SofaPlayerStatistics?
}

private struct SofaPlayer: Decodable {
    let id: Int?
    let name: String?
    let shortName: String?
    let position: String?
    let jerseyNumber: String?
}

private struct SofaPlayerStatistics: Decodable {
    let rating: Double?
}

private struct SofaFeaturedOddsResponse: Decodable {
    let featured: SofaFeaturedOdds?
}

private struct SofaFeaturedOdds: Decodable {
    let defaultMarket: SofaOddsMarket?
    let fullTime: SofaOddsMarket?

    enum CodingKeys: String, CodingKey {
        case defaultMarket = "default"
        case fullTime
    }
}

private struct SofaOddsMarket: Decodable {
    let marketName: String?
    let choices: [SofaOddsChoice]?
}

private struct SofaOddsChoice: Decodable {
    let name: String?
    let fractionalValue: String?
}

private struct SofaMediaResponse: Decodable {
    let media: [SofaMediaItem]?
}

private struct SofaMediaItem: Decodable {
    let title: String?
    let subtitle: String?
    let url: String?
    let thumbnailUrl: String?
    let createdAtTimestamp: Int64?
}

private struct SofaEventNewsResponse: Decodable {
    let newsArticles: [SofaEventNewsArticle]?
}

private struct SofaEventNewsArticle: Decodable {
    let header: String?
    let description: String?
    let thumbnailUrl: String?
    let externalUrl: String?
    let publishedAtTimestamp: Int64?
}

private struct SofaNewsPost: Decodable {
    let title: String?
    let excerpt: String?
    let image: String?
    let link: String?
    let date: String?
}
