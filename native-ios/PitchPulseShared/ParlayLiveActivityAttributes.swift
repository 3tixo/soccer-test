import ActivityKit
import Foundation

struct ParlayLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var progress: String
        var payout: String
        var detail: String
        var updatedAt: Date
    }

    var ticketId: String
    var title: String
}
