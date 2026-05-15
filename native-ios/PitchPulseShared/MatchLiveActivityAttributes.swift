import ActivityKit
import Foundation

struct MatchLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var homeScore: String
        var awayScore: String
        var detail: String
        var isLive: Bool
        var updatedAt: Date
    }

    var matchId: String
    var leagueName: String
    var homeName: String
    var awayName: String
    var homeLogoData: Data?
    var awayLogoData: Data?
}
