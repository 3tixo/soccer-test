import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    @Published private(set) var activeMatchId: String?

    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private init() {
        syncActiveActivity()
    }

    func isActive(event: ScoreEvent) -> Bool {
        activeMatchId == event.id || Activity<MatchLiveActivityAttributes>.activities.contains {
            $0.attributes.matchId == event.id
        }
    }

    func start(event: ScoreEvent, league: League) async {
        guard isSupported else { return }

        await endAll()

        let teams = event.matchTeams
        let homeTeam = teams.home?.team
        let awayTeam = teams.away?.team
        async let homeLogoData = Self.logoData(from: homeTeam?.bestLogo)
        async let awayLogoData = Self.logoData(from: awayTeam?.bestLogo)

        let attributes = MatchLiveActivityAttributes(
            matchId: event.id,
            leagueName: league.name,
            homeName: homeTeam?.bestName ?? "Home",
            awayName: awayTeam?.bestName ?? "Away",
            homeLogoData: await homeLogoData,
            awayLogoData: await awayLogoData
        )
        let content = ActivityContent(
            state: Self.contentState(for: event),
            staleDate: Calendar.current.date(byAdding: .minute, value: 15, to: Date())
        )

        do {
            let activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            activeMatchId = activity.attributes.matchId
        } catch {
            activeMatchId = nil
        }
    }

    func update(event: ScoreEvent) async {
        let content = ActivityContent(
            state: Self.contentState(for: event),
            staleDate: Calendar.current.date(byAdding: .minute, value: 15, to: Date())
        )

        for activity in Activity<MatchLiveActivityAttributes>.activities where activity.attributes.matchId == event.id {
            await activity.update(content)
            activeMatchId = event.id
        }
    }

    func end(event: ScoreEvent) async {
        for activity in Activity<MatchLiveActivityAttributes>.activities where activity.attributes.matchId == event.id {
            await activity.end(ActivityContent(state: Self.contentState(for: event), staleDate: nil), dismissalPolicy: .immediate)
        }
        syncActiveActivity()
    }

    func endAll() async {
        for activity in Activity<MatchLiveActivityAttributes>.activities {
            await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
        }
        activeMatchId = nil
    }

    private func syncActiveActivity() {
        activeMatchId = Activity<MatchLiveActivityAttributes>.activities.first?.attributes.matchId
    }

    nonisolated private static func logoData(from logo: String?) async -> Data? {
        guard let logo,
              !logo.isEmpty,
              let url = URL(string: logo)
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

    private static func contentState(for event: ScoreEvent) -> MatchLiveActivityAttributes.ContentState {
        let teams = event.matchTeams
        let isPre = event.status?.type?.state == "pre"
        let isLive = event.status?.isLive == true
        let detail: String

        if isPre {
            detail = "Kickoff \(kickoffTime(event.date))"
        } else if event.status?.type?.completed == true {
            detail = "Full time"
        } else if isLive {
            detail = "Live now"
        } else {
            detail = event.status?.type?.description ?? "Match"
        }

        return MatchLiveActivityAttributes.ContentState(
            status: event.status?.statusPillText ?? "Scheduled",
            homeScore: isPre ? "-" : (teams.home?.score ?? "-"),
            awayScore: isPre ? "-" : (teams.away?.score ?? "-"),
            detail: detail,
            isLive: isLive,
            updatedAt: Date()
        )
    }
}
