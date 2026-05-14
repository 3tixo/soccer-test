import Foundation
import UserNotifications

@MainActor
final class MatchAlertManager: ObservableObject {
    @Published private(set) var isEnabled: Bool

    private let storageKey = "pitchpulse.native.alerts.enabled"
    private let notificationPrefix = "pitchpulse.native.kickoff."

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: storageKey)
    }

    func toggle(events: [ScoreEvent], league: League) async {
        if isEnabled {
            isEnabled = false
            UserDefaults.standard.set(false, forKey: storageKey)
            cancelKickoffAlerts(events: events)
            return
        }

        let granted = await requestPermission()
        guard granted else { return }

        isEnabled = true
        UserDefaults.standard.set(true, forKey: storageKey)
        scheduleKickoffAlerts(events: events, league: league)
    }

    func refresh(events: [ScoreEvent], league: League) {
        guard isEnabled else { return }
        scheduleKickoffAlerts(events: events, league: league)
    }

    private func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    private func scheduleKickoffAlerts(events: [ScoreEvent], league: League) {
        let center = UNUserNotificationCenter.current()
        let now = Date()
        let upcoming = events
            .filter { $0.status?.type?.state == "pre" }
            .compactMap { event -> (ScoreEvent, Date)? in
                guard let date = event.startDate, date > now.addingTimeInterval(60) else { return nil }
                return (event, date)
            }
            .prefix(20)

        center.removePendingNotificationRequests(withIdentifiers: events.map { notificationPrefix + $0.id })

        upcoming.forEach { event, date in
            let teams = event.matchTeams
            let content = UNMutableNotificationContent()
            content.title = "Kickoff: \(teams.home?.team?.bestName ?? "Home") vs \(teams.away?.team?.bestName ?? "Away")"
            content.body = "\(league.name) starts at \(kickoffTime(event.date))"
            content.sound = .default

            let interval = max(date.timeIntervalSinceNow, 60)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: notificationPrefix + event.id, content: content, trigger: trigger)
            center.add(request)
        }
    }

    private func cancelKickoffAlerts(events: [ScoreEvent]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: events.map { notificationPrefix + $0.id }
        )
    }
}

extension ScoreEvent {
    var startDate: Date? {
        guard let date else { return nil }
        return ISO8601DateFormatter().date(from: date)
    }
}
