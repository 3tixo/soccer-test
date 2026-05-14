import Foundation

enum ESPNError: Error {
    case invalidURL
    case badResponse
}

struct ESPNService {
    private let siteAPI = "https://site.api.espn.com/apis"

    func fetchScoreboard(leagueId: String) async throws -> [ScoreEvent] {
        let response: ScoreboardResponse = try await fetch("\(siteAPI)/site/v2/sports/soccer/\(leagueId)/scoreboard")
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
}

@MainActor
final class ScoreboardViewModel: ObservableObject {
    @Published var selectedLeague = nativeLeagues[0]
    @Published var activeTab: AppTab = .matches
    @Published var searchText = ""
    @Published var events: [ScoreEvent] = []
    @Published var standings: [StandingEntry] = []
    @Published var articles: [NewsArticle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = ESPNService()

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

    func load() async {
        isLoading = true
        errorMessage = nil

        async let eventResult = service.fetchScoreboard(leagueId: selectedLeague.id)
        async let standingResult = service.fetchStandings(leagueId: selectedLeague.id)
        async let newsResult = service.fetchNews(leagueId: selectedLeague.id)

        do {
            events = try await eventResult
            standings = try await standingResult
            articles = try await newsResult
        } catch {
            errorMessage = "Could not load all ESPN data."
            do {
                events = try await service.fetchScoreboard(leagueId: selectedLeague.id)
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
