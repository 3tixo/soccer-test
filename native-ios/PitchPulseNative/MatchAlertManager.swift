import Combine
import Foundation
import UserNotifications

@MainActor
final class MatchAlertManager: ObservableObject {
    @Published private(set) var isEnabled: Bool

    private let storageKey = "pitchpulse.native.alerts.enabled"
    private let notificationPrefix = "pitchpulse.native.kickoff."
    private let liveNotificationPrefix = "pitchpulse.native.live."
    private let finalNotificationPrefix = "pitchpulse.native.final."
    private let deliveredStorageKey = "pitchpulse.native.alerts.delivered.keys"

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: storageKey)
    }

    func toggle(events: [ScoreEvent], league: League, favoriteStore: FavoriteStore) async {
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
        refresh(events: events, league: league, favoriteStore: favoriteStore)
    }

    func refresh(events: [ScoreEvent], league: League, favoriteStore: FavoriteStore) {
        guard isEnabled else { return }
        let monitored = monitoredEvents(from: events, favoriteStore: favoriteStore)
        scheduleKickoffAlerts(events: monitored, league: league)
        sendLiveAndFinalAlerts(events: monitored, league: league, favoriteStore: favoriteStore)
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

            let reminderDate = date.addingTimeInterval(-15 * 60)
            let interval = max(reminderDate.timeIntervalSinceNow, 60)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: notificationPrefix + event.id, content: content, trigger: trigger)
            center.add(request)
        }
    }

    private func sendLiveAndFinalAlerts(events: [ScoreEvent], league: League, favoriteStore: FavoriteStore) {
        var delivered = deliveredKeys
        for event in events where favoriteStore.eventContainsFavorite(event) || !favoriteStore.hasFavorites {
            let teams = event.matchTeams
            guard let homeScore = teams.home?.score, let awayScore = teams.away?.score else { continue }
            let score = "\(homeScore)-\(awayScore)"
            let title = "\(teams.home?.team?.bestName ?? "Home") \(score) \(teams.away?.team?.bestName ?? "Away")"

            if event.status?.isLive == true {
                let key = "\(liveNotificationPrefix)\(event.id).\(score)"
                if !delivered.contains(key) {
                    delivered.insert(key)
                    sendImmediate(identifier: key, title: title, body: "\(league.name) score update")
                }
            }

            if event.status?.type?.completed == true {
                let key = "\(finalNotificationPrefix)\(event.id).\(score)"
                if !delivered.contains(key) {
                    delivered.insert(key)
                    sendImmediate(identifier: key, title: "Full time", body: title)
                }
            }
        }
        deliveredKeys = delivered
    }

    private func sendImmediate(identifier: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    private func monitoredEvents(from events: [ScoreEvent], favoriteStore: FavoriteStore) -> [ScoreEvent] {
        guard favoriteStore.hasFavorites else { return events }
        return events.filter { favoriteStore.eventContainsFavorite($0) }
    }

    private func cancelKickoffAlerts(events: [ScoreEvent]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: events.map { notificationPrefix + $0.id }
        )
    }

    private var deliveredKeys: Set<String> {
        get {
            if let data = UserDefaults.standard.data(forKey: deliveredStorageKey),
               let decoded = try? JSONDecoder().decode([String].self, from: data) {
                return Set(decoded)
            }
            return []
        }
        set {
            if let data = try? JSONEncoder().encode(Array(Array(newValue).suffix(200))) {
                UserDefaults.standard.set(data, forKey: deliveredStorageKey)
            }
        }
    }
}

extension ScoreEvent {
    var startDate: Date? {
        guard let date else { return nil }
        return ISO8601DateFormatter().date(from: date)
    }
}
