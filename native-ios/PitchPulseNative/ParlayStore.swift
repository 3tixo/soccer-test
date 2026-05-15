import Foundation
import ActivityKit
import UserNotifications

enum ParlayLegStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "Pending"
    case hit = "Hit"
    case lost = "Lost"
    case void = "Void"

    var id: String { rawValue }
}

enum ParlayLegType: String, Codable, CaseIterable, Identifiable {
    case homeWin = "Home win"
    case draw = "Draw"
    case awayWin = "Away win"
    case totalGoalsOver = "Total goals over"
    case totalGoalsUnder = "Total goals under"
    case bothTeamsScoreYes = "Both teams score"
    case bothTeamsScoreNo = "Both teams not score"

    var id: String { rawValue }

    var needsLine: Bool {
        self == .totalGoalsOver || self == .totalGoalsUnder
    }

    func marketTitle(event: ScoreEvent) -> String {
        switch self {
        case .homeWin, .draw, .awayWin:
            return "Match winner"
        case .totalGoalsOver, .totalGoalsUnder:
            return "Total goals"
        case .bothTeamsScoreYes, .bothTeamsScoreNo:
            return "Both teams to score"
        }
    }

    func pickTitle(event: ScoreEvent, line: Double?) -> String {
        let teams = event.matchTeams
        switch self {
        case .homeWin:
            return teams.home?.team?.bestName ?? "Home"
        case .draw:
            return "Draw"
        case .awayWin:
            return teams.away?.team?.bestName ?? "Away"
        case .totalGoalsOver:
            return "Over \(formatLine(line))"
        case .totalGoalsUnder:
            return "Under \(formatLine(line))"
        case .bothTeamsScoreYes:
            return "Yes"
        case .bothTeamsScoreNo:
            return "No"
        }
    }

    private func formatLine(_ line: Double?) -> String {
        guard let line else { return "2.5" }
        return line.formatted(.number.precision(.fractionLength(1)))
    }
}

struct ParlayLeg: Identifiable, Codable, Hashable {
    var id = UUID()
    var eventId: String
    var matchName: String
    var market: String
    var pick: String
    var type: ParlayLegType?
    var line: Double?
    var multiplier: Double
    var status: ParlayLegStatus
}

struct ParlayTicket: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var stake: Double
    var legs: [ParlayLeg]
    var createdAt = Date()

    var totalMultiplier: Double {
        legs.map { max($0.multiplier, 1) }.reduce(1, *)
    }

    var potentialPayout: Double {
        stake * totalMultiplier
    }

    var status: ParlayLegStatus {
        if legs.contains(where: { $0.status == .lost }) { return .lost }
        if !legs.isEmpty && legs.allSatisfy({ $0.status == .hit || $0.status == .void }) { return .hit }
        return .pending
    }

    var progressText: String {
        "\(legs.filter { $0.status == .hit }.count)/\(legs.count) legs"
    }
}

@MainActor
final class ParlayStore: ObservableObject {
    @Published private(set) var tickets: [ParlayTicket] = []

    private let storageKey = "pulse.native.parlay.tickets"
    private let autoNotificationKey = "pulse.native.parlay.auto.notification.keys"

    init() {
        load()
    }

    func add(_ ticket: ParlayTicket) {
        tickets.insert(ticket, at: 0)
        persist()
    }

    func refresh(events: [ScoreEvent]) {
        guard !events.isEmpty, !tickets.isEmpty else { return }
        var eventsById: [String: ScoreEvent] = [:]
        for event in events {
            eventsById[event.id] = event
        }
        var changedTickets: [ParlayTicket] = []

        for ticketIndex in tickets.indices {
            var changed = false
            for legIndex in tickets[ticketIndex].legs.indices {
                guard tickets[ticketIndex].legs[legIndex].status == .pending,
                      let event = eventsById[tickets[ticketIndex].legs[legIndex].eventId],
                      let resolvedStatus = evaluatedStatus(for: tickets[ticketIndex].legs[legIndex], event: event)
                else { continue }

                tickets[ticketIndex].legs[legIndex].status = resolvedStatus
                changed = true
            }

            if changed {
                changedTickets.append(tickets[ticketIndex])
            }
        }

        guard !changedTickets.isEmpty else { return }
        persist()
        for ticket in changedTickets {
            Task { await updateLiveActivity(for: ticket) }
            sendAutoNotificationIfNeeded(for: ticket)
        }
    }

    func updateLeg(ticketId: UUID, legId: UUID, status: ParlayLegStatus) {
        guard let ticketIndex = tickets.firstIndex(where: { $0.id == ticketId }),
              let legIndex = tickets[ticketIndex].legs.firstIndex(where: { $0.id == legId })
        else { return }
        tickets[ticketIndex].legs[legIndex].status = status
        persist()
        let ticket = tickets[ticketIndex]
        Task { await updateLiveActivity(for: ticket) }
    }

    func delete(_ ticket: ParlayTicket) {
        tickets.removeAll { $0.id == ticket.id }
        persist()
    }

    func requestNotificationPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func sendStatusNotification(for ticket: ParlayTicket) {
        let content = UNMutableNotificationContent()
        content.title = ticket.status == .hit ? "Parlay hit" : "Parlay update"
        content.body = "\(ticket.title): \(ticket.progressText), payout \(currency(ticket.potentialPayout))"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "pulse.native.parlay.\(ticket.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    func startLiveActivity(for ticket: ParlayTicket) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        await endLiveActivity(for: ticket)

        do {
            _ = try Activity.request(
                attributes: ParlayLiveActivityAttributes(ticketId: ticket.id.uuidString, title: ticket.title),
                content: ActivityContent(state: liveActivityState(for: ticket), staleDate: nil),
                pushType: nil
            )
        } catch {
            return
        }
    }

    func updateLiveActivity(for ticket: ParlayTicket) async {
        for activity in Activity<ParlayLiveActivityAttributes>.activities where activity.attributes.ticketId == ticket.id.uuidString {
            await activity.update(ActivityContent(state: liveActivityState(for: ticket), staleDate: nil))
        }
    }

    func endLiveActivity(for ticket: ParlayTicket) async {
        for activity in Activity<ParlayLiveActivityAttributes>.activities where activity.attributes.ticketId == ticket.id.uuidString {
            await activity.end(ActivityContent(state: liveActivityState(for: ticket), staleDate: nil), dismissalPolicy: .immediate)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ParlayTicket].self, from: data)
        else { return }
        tickets = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(tickets) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func evaluatedStatus(for leg: ParlayLeg, event: ScoreEvent) -> ParlayLegStatus? {
        guard let type = leg.type else { return nil }
        let teams = event.matchTeams
        guard let homeScore = Int(teams.home?.score ?? ""),
              let awayScore = Int(teams.away?.score ?? "")
        else { return nil }

        let total = homeScore + awayScore
        let isFinal = event.status?.type?.completed == true

        switch type {
        case .totalGoalsOver:
            guard let line = leg.line else { return nil }
            if Double(total) > line { return .hit }
            return isFinal ? .lost : nil
        case .bothTeamsScoreYes:
            if homeScore > 0 && awayScore > 0 { return .hit }
            return isFinal ? .lost : nil
        case .homeWin, .draw, .awayWin, .totalGoalsUnder, .bothTeamsScoreNo:
            guard isFinal else { return nil }
            switch type {
            case .homeWin:
                return homeScore > awayScore ? .hit : .lost
            case .draw:
                return homeScore == awayScore ? .hit : .lost
            case .awayWin:
                return awayScore > homeScore ? .hit : .lost
            case .totalGoalsUnder:
                guard let line = leg.line else { return nil }
                return Double(total) < line ? .hit : .lost
            case .bothTeamsScoreNo:
                return homeScore == 0 || awayScore == 0 ? .hit : .lost
            case .totalGoalsOver, .bothTeamsScoreYes:
                return nil
            }
        }
    }

    private func sendAutoNotificationIfNeeded(for ticket: ParlayTicket) {
        guard ticket.status == .hit || ticket.status == .lost else { return }
        let key = "\(ticket.id.uuidString).\(ticket.status.rawValue)"
        var sent = autoNotificationKeys
        guard !sent.contains(key) else { return }
        sent.insert(key)
        autoNotificationKeys = sent
        sendStatusNotification(for: ticket)
    }

    private var autoNotificationKeys: Set<String> {
        get {
            guard let data = UserDefaults.standard.data(forKey: autoNotificationKey),
                  let decoded = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return Set(decoded)
        }
        set {
            if let data = try? JSONEncoder().encode(Array(Array(newValue).suffix(200))) {
                UserDefaults.standard.set(data, forKey: autoNotificationKey)
            }
        }
    }

    private func liveActivityState(for ticket: ParlayTicket) -> ParlayLiveActivityAttributes.ContentState {
        ParlayLiveActivityAttributes.ContentState(
            status: ticket.status.rawValue,
            progress: ticket.progressText,
            payout: currency(ticket.potentialPayout),
            detail: ticket.legs.first?.pick ?? "Ticket",
            updatedAt: Date()
        )
    }
}

func currency(_ value: Double) -> String {
    value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
}
