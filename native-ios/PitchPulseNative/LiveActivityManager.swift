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
        let attributes = MatchLiveActivityAttributes(
            matchId: event.id,
            leagueName: league.name,
            homeName: teams.home?.team?.bestName ?? "Home",
            awayName: teams.away?.team?.bestName ?? "Away"
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
