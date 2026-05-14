import Foundation

enum ESPNError: Error {
    case invalidURL
    case badResponse
}

struct ESPNService {
    private let siteAPI = "https://site.api.espn.com/apis"

    func fetchScoreboard(leagueId: String, date: Date) async throws -> [ScoreEvent] {
        let response: ScoreboardResponse = try await fetch("\(siteAPI)/site/v2/sports/soccer/\(leagueId)/scoreboard?dates=\(Self.apiDate(date))")
        return response.events ?? []
    }

    func fetchStandings(leagueId: String) async throws -> [StandingEntry] {
        let response: StandingsResponse = try await fetch("\(siteAPI)/v2/sports/soccer/\(leagueId)/standings")
        if let entries = response.standings?.entries, !entries.isEmpty {
            return entries
        }
        return (response.children ?? []).flatMap { $0.standings?.entries ?? [] }
    }

    func fetchNews(leagueId: String) async throws -> [NewsArticle] {
        let response: NewsResponse = try await fetch("\(siteAPI)/site/v2/sports/soccer/\(leagueId)/news")
        return response.articles ?? []
    }

    func fetchSummary(leagueId: String, eventId: String) async throws -> MatchSummary {
        try await fetch("\(siteAPI)/site/v2/sports/soccer/\(leagueId)/summary?event=\(eventId)")
    }

    private func fetch<T: Decodable>(_ urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw ESPNError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ESPNError.badResponse
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    static func apiDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}

@MainActor
final class ScoreboardViewModel: ObservableObject {
    @Published var selectedLeague = nativeLeagues[0]
    @Published var selectedDate = Date()
    @Published var activeTab: AppTab = .matches
    @Published var searchText = ""
    @Published var events: [ScoreEvent] = []
    @Published var standings: [StandingEntry] = []
    @Published var articles: [NewsArticle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = ESPNService()

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var dateLabel: String {
        selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    var filteredEvents: [ScoreEvent] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return events }
        return events.filter { event in
            event.searchText.contains(query)
        }
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
        searchText = ""
        await load()
    }

    func shiftDate(by days: Int) async {
        selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
        await load()
    }

    func goToToday() async {
        selectedDate = Date()
        await load()
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

    func load() async {
        isLoading = true
        errorMessage = nil

        async let eventResult = service.fetchScoreboard(leagueId: selectedLeague.id, date: selectedDate)
        async let standingResult = service.fetchStandings(leagueId: selectedLeague.id)
        async let newsResult = service.fetchNews(leagueId: selectedLeague.id)

        do {
            events = try await eventResult
            standings = try await standingResult
            articles = try await newsResult
        } catch {
            errorMessage = "Could not load all ESPN data."
            do {
                events = try await service.fetchScoreboard(leagueId: selectedLeague.id, date: selectedDate)
            } catch {
                events = []
            }
            do {
                standings = try await service.fetchStandings(leagueId: selectedLeague.id)
            } catch {
                standings = []
            }
            do {
                articles = try await service.fetchNews(leagueId: selectedLeague.id)
            } catch {
                articles = []
            }
        }

        isLoading = false
    }
}

extension ScoreEvent {
    var searchText: String {
        let competitors = competition?.competitors ?? []
        let teams = competitors.map { $0.team?.bestName ?? "" }.joined(separator: " ")
        return "\(name ?? "") \(shortName ?? "") \(teams)".lowercased()
    }
}
