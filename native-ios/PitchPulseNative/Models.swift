import Foundation

struct League: Identifiable, Hashable {
    let id: String
    let name: String
    let country: String
}

let nativeLeagues: [League] = [
    League(id: "eng.1", name: "Premier League", country: "England"),
    League(id: "esp.1", name: "LALIGA", country: "Spain"),
    League(id: "ita.1", name: "Serie A", country: "Italy"),
    League(id: "ger.1", name: "Bundesliga", country: "Germany"),
    League(id: "fra.1", name: "Ligue 1", country: "France"),
    League(id: "uefa.champions", name: "Champions League", country: "Europe"),
    League(id: "usa.1", name: "MLS", country: "United States")
]

struct ScoreboardResponse: Decodable {
    let events: [ScoreEvent]?
}

struct ScoreEvent: Identifiable, Decodable {
    let id: String
    let name: String?
    let shortName: String?
    let date: String?
    let status: EventStatus?
    let competitions: [Competition]?

    var competition: Competition? {
        competitions?.first
    }
}

struct EventStatus: Decodable {
    let type: StatusType?
}

struct StatusType: Decodable {
    let state: String?
    let completed: Bool?
    let description: String?
    let shortDetail: String?
}

struct Competition: Decodable {
    let competitors: [Competitor]?
    let venue: Venue?
}

struct Venue: Decodable {
    let fullName: String?
    let displayName: String?
}

struct Competitor: Decodable, Identifiable {
    let id: String?
    let homeAway: String?
    let score: String?
    let team: Team?
    let records: [TeamRecord]?

    var displayId: String {
        id ?? team?.id ?? UUID().uuidString
    }
}

struct Team: Decodable {
    let id: String?
    let displayName: String?
    let shortDisplayName: String?
    let abbreviation: String?
    let logo: String?
    let logos: [TeamLogo]?
}

struct TeamLogo: Decodable {
    let href: String?
}

struct TeamRecord: Decodable {
    let summary: String?
}
