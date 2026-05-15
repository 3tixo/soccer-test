import Foundation

struct League: Identifiable, Hashable {
    let id: String
    let name: String
    let country: String
}

let nativeLeagues: [League] = [
    League(id: "17", name: "Premier League", country: "England"),
    League(id: "8", name: "LALIGA", country: "Spain"),
    League(id: "23", name: "Serie A", country: "Italy"),
    League(id: "35", name: "Bundesliga", country: "Germany"),
    League(id: "34", name: "Ligue 1", country: "France"),
    League(id: "7", name: "Champions League", country: "Europe"),
    League(id: "679", name: "Europa League", country: "Europe"),
    League(id: "242", name: "MLS", country: "United States")
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
    let displayClock: String?
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
        id ?? team?.stableId ?? "\(homeAway ?? "team")-\(team?.bestName ?? "unknown")"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case homeAway
        case score
        case winner
        case team
        case records
        case record
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        homeAway = try container.decodeIfPresent(String.self, forKey: .homeAway)
        score = container.decodeFlexibleScore(forKey: .score)
        winner = try container.decodeIfPresent(Bool.self, forKey: .winner)
        team = try container.decodeIfPresent(Team.self, forKey: .team)
        records = (try? container.decodeIfPresent([TeamRecord].self, forKey: .records))
            ?? (try? container.decodeIfPresent([TeamRecord].self, forKey: .record))
    }

    init(id: String?, homeAway: String?, score: String?, winner: Bool?, team: Team?, records: [TeamRecord]?) {
        self.id = id
        self.homeAway = homeAway
        self.score = score
        self.winner = winner
        self.team = team
        self.records = records
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
    let color: String?
    let alternateColor: String?
    let recordSummary: String?
    let standingSummary: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case shortDisplayName
        case name
        case abbreviation
        case logo
        case logos
        case color
        case alternateColor
        case recordSummary
        case standingSummary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        shortDisplayName = try container.decodeIfPresent(String.self, forKey: .shortDisplayName)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        abbreviation = try container.decodeIfPresent(String.self, forKey: .abbreviation)
        logo = try? container.decodeIfPresent(String.self, forKey: .logo)
        logos = try? container.decodeIfPresent([TeamLogo].self, forKey: .logos)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        alternateColor = try container.decodeIfPresent(String.self, forKey: .alternateColor)
        recordSummary = try container.decodeIfPresent(String.self, forKey: .recordSummary)
        standingSummary = try container.decodeIfPresent(String.self, forKey: .standingSummary)
    }

    init(
        id: String?,
        displayName: String?,
        shortDisplayName: String?,
        name: String?,
        abbreviation: String?,
        logo: String?,
        logos: [TeamLogo]?,
        color: String?,
        alternateColor: String?,
        recordSummary: String?,
        standingSummary: String?
    ) {
        self.id = id
        self.displayName = displayName
        self.shortDisplayName = shortDisplayName
        self.name = name
        self.abbreviation = abbreviation
        self.logo = logo
        self.logos = logos
        self.color = color
        self.alternateColor = alternateColor
        self.recordSummary = recordSummary
        self.standingSummary = standingSummary
    }

    var bestName: String {
        shortDisplayName ?? displayName ?? name ?? "TBA"
    }

    var bestLogo: String {
        logo ?? logos?.first?.href ?? ""
    }

    var stableId: String {
        id ?? displayName ?? shortDisplayName ?? name ?? abbreviation ?? "unknown-team"
    }
}

struct TeamLogo: Decodable {
    let href: String?
}

struct TeamRecord: Decodable {
    let summary: String?
    let displayValue: String?
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
        team?.stableId ?? note?.description ?? "standing-entry"
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

    init(name: String?, displayName: String?, displayValue: String?, summary: String?, value: Double?) {
        self.name = name
        self.displayName = displayName
        self.displayValue = displayValue
        self.summary = summary
        self.value = value
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
        links?.web?.href ?? [headline, published, description].compactMap { $0 }.joined(separator: "-")
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
    let shotmap: [ShotMapItem]?
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

struct ShotMapItem: Decodable, Identifiable {
    let id: String
    let isHome: Bool?
    let player: ShotPlayer?
    let playerCoordinates: ShotCoordinates?
    let goalMouthCoordinates: ShotCoordinates?
    let shotType: String?
    let situation: String?
    let bodyPart: String?
    let goalMouthLocation: String?
    let xg: Double?
    let xgot: Double?
    let time: Int?
    let addedTime: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case isHome
        case player
        case playerCoordinates
        case goalMouthCoordinates
        case shotType
        case situation
        case bodyPart
        case goalMouthLocation
        case xg
        case xG
        case xgot
        case xGOT
        case time
        case addedTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let id = try? container.decodeIfPresent(Int.self, forKey: .id) {
            self.id = String(id)
        } else if let id = try? container.decodeIfPresent(Int64.self, forKey: .id) {
            self.id = String(id)
        } else {
            self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        }
        isHome = try container.decodeIfPresent(Bool.self, forKey: .isHome)
        player = try container.decodeIfPresent(ShotPlayer.self, forKey: .player)
        playerCoordinates = try container.decodeIfPresent(ShotCoordinates.self, forKey: .playerCoordinates)
        goalMouthCoordinates = try container.decodeIfPresent(ShotCoordinates.self, forKey: .goalMouthCoordinates)
        shotType = try container.decodeIfPresent(String.self, forKey: .shotType)
        situation = try container.decodeIfPresent(String.self, forKey: .situation)
        bodyPart = try container.decodeIfPresent(String.self, forKey: .bodyPart)
        goalMouthLocation = try container.decodeIfPresent(String.self, forKey: .goalMouthLocation)
        xg = container.decodeFlexibleDouble(forKey: .xg) ?? container.decodeFlexibleDouble(forKey: .xG)
        xgot = container.decodeFlexibleDouble(forKey: .xgot) ?? container.decodeFlexibleDouble(forKey: .xGOT)
        time = container.decodeFlexibleInt(forKey: .time)
        addedTime = container.decodeFlexibleInt(forKey: .addedTime)
    }
}

struct ShotPlayer: Decodable {
    let name: String?
    let shortName: String?

    var bestName: String {
        shortName ?? name ?? "Player"
    }
}

struct ShotCoordinates: Decodable {
    let x: Double?
    let y: Double?
    let z: Double?

    enum CodingKeys: String, CodingKey {
        case x
        case y
        case z
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = container.decodeFlexibleDouble(forKey: .x)
        y = container.decodeFlexibleDouble(forKey: .y)
        z = container.decodeFlexibleDouble(forKey: .z)
    }
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

    init(name: String?, displayName: String?, shortDisplayName: String?, displayValue: String?, value: Double?) {
        self.name = name
        self.displayName = displayName
        self.shortDisplayName = shortDisplayName
        self.displayValue = displayValue
        self.value = value
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
        "\(homeAway ?? "side")-\(team?.stableId ?? formation ?? "unknown")"
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

    init(
        athlete: Athlete?,
        jersey: String?,
        starter: Bool?,
        position: PlayerPosition?,
        formationPlace: Int?,
        subbedIn: Bool?,
        subbedOut: Bool?,
        stats: [GameStatistic]?
    ) {
        self.athlete = athlete
        self.jersey = jersey
        self.starter = starter
        self.position = position
        self.formationPlace = formationPlace
        self.subbedIn = subbedIn
        self.subbedOut = subbedOut
        self.stats = stats
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

    func decodeFlexibleScore(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(Int(value))
        }
        if let value = try? decodeIfPresent(ScoreObject.self, forKey: key) {
            return value.displayValue ?? value.value.map { String(Int($0)) }
        }
        return nil
    }
}

private struct ScoreObject: Decodable {
    let value: Double?
    let displayValue: String?
}
