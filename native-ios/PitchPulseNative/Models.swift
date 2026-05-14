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
    League(id: "uefa.europa", name: "Europa League", country: "Europe"),
    League(id: "usa.1", name: "MLS", country: "United States")
]

enum AppTab: String, CaseIterable, Identifiable {
    case matches = "Matches"
    case table = "Table"
    case news = "News"

    var id: String { rawValue }
}

struct ScoreboardResponse: Decodable {
    let day: ScoreboardDay?
    let events: [ScoreEvent]?
}

struct ScoreboardDay: Decodable {
    let date: String?
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
    let winner: Bool?
    let team: Team?
    let records: [TeamRecord]?

    var stableId: String {
        id ?? team?.id ?? "\(homeAway ?? "team")-\(team?.displayName ?? UUID().uuidString)"
    }
}

struct Team: Decodable {
    let id: String?
    let displayName: String?
    let shortDisplayName: String?
    let name: String?
    let abbreviation: String?
    let logo: String?
    let logos: [TeamLogo]?

    var bestName: String {
        shortDisplayName ?? displayName ?? name ?? "TBA"
    }

    var bestLogo: String {
        logo ?? logos?.first?.href ?? ""
    }

    var stableId: String {
        id ?? displayName ?? shortDisplayName ?? name ?? UUID().uuidString
    }
}

struct TeamLogo: Decodable {
    let href: String?
}

struct TeamRecord: Decodable {
    let summary: String?
}

struct StandingsResponse: Decodable {
    let children: [StandingChild]?
    let standings: StandingGroup?
}

struct StandingChild: Decodable {
    let standings: StandingGroup?
}

struct StandingGroup: Decodable {
    let entries: [StandingEntry]?
}

struct StandingEntry: Decodable, Identifiable {
    let team: Team?
    let stats: [StandingStat]?
    let note: StandingNote?

    var id: String {
        team?.id ?? team?.displayName ?? UUID().uuidString
    }
}

struct StandingNote: Decodable {
    let description: String?
    let color: String?
}

struct StandingStat: Decodable {
    let name: String?
    let displayName: String?
    let displayValue: String?
    let summary: String?
    let value: Double?

    enum CodingKeys: String, CodingKey {
        case name
        case displayName
        case displayValue
        case summary
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        displayValue = try container.decodeIfPresent(String.self, forKey: .displayValue)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        value = container.decodeFlexibleDouble(forKey: .value)
    }
}

struct NewsResponse: Decodable {
    let articles: [NewsArticle]?
}

struct TeamProfileResponse: Decodable {
    let team: Team?
}

struct TeamScheduleResponse: Decodable {
    let team: Team?
    let events: [ScoreEvent]?
}

struct NewsArticle: Identifiable, Decodable {
    let headline: String?
    let description: String?
    let images: [ArticleImage]?
    let links: ArticleLinks?
    let published: String?

    var id: String {
        links?.web?.href ?? headline ?? UUID().uuidString
    }
}

struct ArticleImage: Decodable {
    let url: String?
}

struct ArticleLinks: Decodable {
    let web: ArticleLink?
}

struct ArticleLink: Decodable {
    let href: String?
}

struct MatchSummary: Decodable {
    let keyEvents: [TimelineEvent]?
    let commentary: [CommentaryItem]?
    let boxscore: Boxscore?
    let news: NewsResponse?
    let odds: [OddsItem]?
    let rosters: [RosterGroup]?
}

struct CommentaryItem: Decodable {
    let play: TimelineEvent?
}

struct TimelineEvent: Identifiable, Decodable {
    let id: String?
    let text: String?
    let shortText: String?
    let type: TimelineType?
    let clock: TimelineClock?
    let time: TimelineClock?
    let team: Team?

    var stableId: String {
        id ?? "\(type?.type ?? "event")-\(clock?.displayValue ?? time?.displayValue ?? "")-\(text ?? "")"
    }
}

struct TimelineType: Decodable {
    let type: String?
    let text: String?
}

struct TimelineClock: Decodable {
    let displayValue: String?
    let value: Double?
}

struct Boxscore: Decodable {
    let teams: [BoxscoreTeam]?
}

struct BoxscoreTeam: Decodable {
    let team: Team?
    let statistics: [GameStatistic]?
}

struct GameStatistic: Decodable {
    let name: String?
    let displayName: String?
    let shortDisplayName: String?
    let displayValue: String?
    let value: Double?

    enum CodingKeys: String, CodingKey {
        case name
        case displayName
        case shortDisplayName
        case displayValue
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        shortDisplayName = try container.decodeIfPresent(String.self, forKey: .shortDisplayName)
        displayValue = try container.decodeIfPresent(String.self, forKey: .displayValue)
        value = container.decodeFlexibleDouble(forKey: .value)
    }
}

struct OddsItem: Decodable {
    let provider: OddsProvider?
    let header: OddsHeader?
    let details: String?
    let overUnder: FlexibleOddsValue?
    let homeTeamOdds: TeamOdds?
    let awayTeamOdds: TeamOdds?
    let drawOdds: DrawOdds?
    let moneyline: MoneylineMarket?
}

struct OddsProvider: Decodable {
    let name: String?
}

struct OddsHeader: Decodable {
    let text: String?
}

struct TeamOdds: Decodable {
    let moneyLine: FlexibleOddsValue?
    let odds: OddsSummary?
}

struct DrawOdds: Decodable {
    let moneyLine: FlexibleOddsValue?
    let summary: FlexibleOddsValue?
}

struct OddsSummary: Decodable {
    let summary: FlexibleOddsValue?
}

struct MoneylineMarket: Decodable {
    let home: MoneylineSide?
    let away: MoneylineSide?
    let draw: MoneylineSide?
}

struct MoneylineSide: Decodable {
    let close: OddsClose?
}

struct OddsClose: Decodable {
    let odds: FlexibleOddsValue?
}

enum FlexibleOddsValue: Decodable {
    case number(Double)
    case text(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) {
            self = .number(number)
            return
        }
        if let string = try? container.decode(String.self) {
            self = .text(string)
            return
        }
        self = .text("")
    }
}

struct TeamDetailContext: Identifiable {
    let team: Team
    let standing: StandingEntry?
    let events: [ScoreEvent]
    let articles: [NewsArticle]

    var id: String {
        team.stableId
    }
}

struct RosterGroup: Decodable, Identifiable {
    let team: Team?
    let homeAway: String?
    let formation: String?
    let roster: [RosterPlayer]?

    var id: String {
        "\(homeAway ?? "side")-\(team?.stableId ?? UUID().uuidString)"
    }
}

struct RosterPlayer: Decodable, Identifiable {
    let athlete: Athlete?
    let jersey: String?
    let starter: Bool?
    let position: PlayerPosition?
    let formationPlace: Int?
    let subbedIn: Bool?
    let subbedOut: Bool?
    let stats: [GameStatistic]?

    var id: String {
        athlete?.id ?? "\(athlete?.displayName ?? "player")-\(jersey ?? "")"
    }

    enum CodingKeys: String, CodingKey {
        case athlete
        case jersey
        case starter
        case position
        case formationPlace
        case subbedIn
        case subbedOut
        case stats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        athlete = try container.decodeIfPresent(Athlete.self, forKey: .athlete)
        jersey = try container.decodeIfPresent(String.self, forKey: .jersey)
        starter = try container.decodeIfPresent(Bool.self, forKey: .starter)
        position = try container.decodeIfPresent(PlayerPosition.self, forKey: .position)
        formationPlace = container.decodeFlexibleInt(forKey: .formationPlace)
        subbedIn = try container.decodeIfPresent(Bool.self, forKey: .subbedIn)
        subbedOut = try container.decodeIfPresent(Bool.self, forKey: .subbedOut)
        stats = try container.decodeIfPresent([GameStatistic].self, forKey: .stats)
    }
}

struct Athlete: Decodable {
    let id: String?
    let displayName: String?
    let shortName: String?
    let headshot: Headshot?

    var bestName: String {
        shortName ?? displayName ?? "Player"
    }
}

struct Headshot: Decodable {
    let href: String?
}

struct PlayerPosition: Decodable {
    let abbreviation: String?
    let displayName: String?
}

extension KeyedDecodingContainer {
    func decodeFlexibleDouble(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value.replacingOccurrences(of: "%", with: ""))
        }
        return nil
    }

    func decodeFlexibleInt(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }
        return nil
    }
}
