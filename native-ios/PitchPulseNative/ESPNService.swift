import Foundation

enum ESPNError: Error {
    case invalidURL
    case badResponse
}

struct ESPNService {
    func fetchScoreboard(leagueId: String) async throws -> [ScoreEvent] {
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/soccer/\(leagueId)/scoreboard") else {
            throw ESPNError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ESPNError.badResponse
        }

        let decoded = try JSONDecoder().decode(ScoreboardResponse.self, from: data)
        return decoded.events ?? []
    }
}

@MainActor
final class ScoreboardViewModel: ObservableObject {
    @Published var selectedLeague = nativeLeagues[0]
    @Published var events: [ScoreEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = ESPNService()

    func select(_ league: League) {
        selectedLeague = league
        Task {
            await load()
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            events = try await service.fetchScoreboard(leagueId: selectedLeague.id)
        } catch {
            events = []
            errorMessage = "Could not load ESPN scores."
        }

        isLoading = false
    }
}
