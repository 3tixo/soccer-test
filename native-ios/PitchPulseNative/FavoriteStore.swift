import Combine
import Foundation

@MainActor
final class FavoriteStore: ObservableObject {
    @Published private(set) var teamIds: Set<String>

    private let storageKey = "pitchpulse.native.favorite.team.ids"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            teamIds = Set(decoded)
        } else {
            teamIds = []
        }
    }

    func contains(_ team: Team?) -> Bool {
        guard let id = team?.stableId else { return false }
        return teamIds.contains(id)
    }

    func toggle(_ team: Team?) {
        guard let id = team?.stableId else { return }
        if teamIds.contains(id) {
            teamIds.remove(id)
        } else {
            teamIds.insert(id)
        }
        persist()
    }

    func eventContainsFavorite(_ event: ScoreEvent) -> Bool {
        (event.competition?.competitors ?? []).contains { competitor in
            contains(competitor.team)
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(Array(teamIds)) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
