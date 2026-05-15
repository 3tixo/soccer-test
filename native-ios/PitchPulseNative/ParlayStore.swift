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

struct ParlayLeg: Identifiable, Codable, Hashable {
    var id = UUID()
    var eventId: String
    var matchName: String
    var market: String
    var pick: String
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

    init() {
        load()
    }

    func add(_ ticket: ParlayTicket) {
        tickets.insert(ticket, at: 0)
        persist()
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
