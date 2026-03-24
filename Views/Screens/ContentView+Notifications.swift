import SwiftUI
import UserNotifications

extension ContentView {
    var notificationEventYear: Int {
        challengeDefinitions.first?.year ?? Calendar.current.component(.year, from: Date())
    }

    var notificationEventStartDate: Date? {
        notificationDate(month: 5, day: 21, hour: 0, minute: 0)
    }

    var notificationOfficialOpeningDate: Date? {
        notificationDate(month: 5, day: 21, hour: 17, minute: 0)
    }

    func notificationDate(month: Int, day: Int, hour: Int, minute: Int) -> Date? {
        BergscheinDateHelper.date(
            year: notificationEventYear,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
    }

    func applyPendingNotificationDestinationIfNeeded() {
        guard let destination = NotificationNavigationStore.shared.consumePendingDestination() else {
            return
        }
        openNotificationDestination(destination)
    }

    func openNotificationDestination(_ destination: NotificationDestination) {
        switch destination {
        case .challenge:
            selectedTab = .challenge
        }
    }

    func refreshScheduledNotifications() {
        guard hasSeenOnboarding else {
            return
        }

        Task {
            await scheduleLocalNotifications()
        }
    }

    func refreshNotificationAuthorizationState() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            let isSystemAvailable = settings.authorizationStatus != .denied

            await MainActor.run {
                notificationsAreSystemAuthorized = isSystemAvailable

                if !isSystemAvailable {
                    notificationsEnabled = false
                    stampNotificationsEnabled = false
                    challengeNotificationsEnabled = false
                }
            }
        }
    }

    func scheduleLocalNotifications() async {
        let center = UNUserNotificationCenter.current()

        do {
            await removeManagedNotificationRequests(from: center)

            let settings = await center.notificationSettings()
            let isSystemAvailable = settings.authorizationStatus != .denied

            await MainActor.run {
                notificationsAreSystemAuthorized = isSystemAvailable
            }

            guard isSystemAvailable else {
                await MainActor.run {
                    notificationsEnabled = false
                    stampNotificationsEnabled = false
                    challengeNotificationsEnabled = false
                }
                return
            }

            guard notificationsEnabled else {
                return
            }
            let isAuthorized: Bool

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                isAuthorized = true
            case .notDetermined:
                isAuthorized = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            case .denied:
                isAuthorized = false
            @unknown default:
                isAuthorized = false
            }

            await MainActor.run {
                notificationsAreSystemAuthorized = isAuthorized
            }

            guard isAuthorized else {
                await MainActor.run {
                    notificationsEnabled = false
                    stampNotificationsEnabled = false
                    challengeNotificationsEnabled = false
                }
                return
            }

            for request in makeNotificationRequests() {
                try await center.add(request)
            }
        } catch {
        }
    }

    func removeManagedNotificationRequests(from center: UNUserNotificationCenter) async {
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("bergschein.") }

        guard !identifiers.isEmpty else {
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func makeNotificationRequests(now: Date = Date()) -> [UNNotificationRequest] {
        var requests: [UNNotificationRequest] = []

        if let officialOpeningDate = notificationOfficialOpeningDate, officialOpeningDate > now {
            let content = UNMutableNotificationContent()
            content.title = "Jetzt Anstich!"
            content.body = "Der Berg startet jetzt für dieses Jahr. Hol dir deinen ersten Stempel."
            content.sound = .default

            if let trigger = calendarTrigger(for: officialOpeningDate) {
                requests.append(
                    UNNotificationRequest(
                        identifier: "bergschein.event-start",
                        content: content,
                        trigger: trigger
                    )
                )
            }
        }

        if stampNotificationsEnabled {
            for badge in badgeDefinitions where !unlockedBadges.contains(badge.id) {
                guard let reminderDate = notificationDate(month: badge.month, day: badge.day, hour: 19, minute: 0),
                      reminderDate > now else {
                    continue
                }

                let content = UNMutableNotificationContent()
                content.title = "Stempel für heute noch offen"
                content.body = "Hol dir den Stempel für den \(badge.name), solange der Bergtag noch läuft."
                content.sound = .default

                if let trigger = calendarTrigger(for: reminderDate) {
                    requests.append(
                        UNNotificationRequest(
                            identifier: "bergschein.stamp.\(badge.id)",
                            content: content,
                            trigger: trigger
                        )
                    )
                }
            }
        }

        if challengeNotificationsEnabled {
            for challenge in challengeDefinitions {
                guard let reminderDate = Calendar.current.date(
                    bySettingHour: 10,
                    minute: 0,
                    second: 0,
                    of: challenge.date
                ), reminderDate > now else {
                    continue
                }

                let content = UNMutableNotificationContent()
                content.title = "Heutige Challenge"
                content.body = challengeNotificationBody(for: challenge)
                content.sound = .default
                content.userInfo = ["destination": NotificationDestination.challenge.rawValue]

                if let trigger = calendarTrigger(for: reminderDate) {
                    requests.append(
                        UNNotificationRequest(
                            identifier: "bergschein.challenge.\(challenge.id)",
                            content: content,
                            trigger: trigger
                        )
                    )
                }
            }
        }

        return requests
    }

    func challengeNotificationBody(for challenge: DailyChallenge) -> String {
        if challenge.title == "Challenge folgt" {
            return "Heute wartet wieder eine Challenge auf dich. Schau direkt im Challenge-Tab vorbei."
        }

        return "Heute: \(challenge.title). Schau direkt im Challenge-Tab vorbei."
    }

    func calendarTrigger(for date: Date) -> UNCalendarNotificationTrigger? {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}
