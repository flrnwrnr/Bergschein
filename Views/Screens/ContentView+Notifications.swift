import SwiftUI
import UserNotifications

extension ContentView {
    func notificationDate(
        in season: SeasonDefinition,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) -> Date? {
        BergscheinDateHelper.date(
            year: season.openingAt.year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            calendar: season.calendar
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
            #if DEBUG
            print("Notification scheduling failed: \(error)")
            #endif
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

    func makeNotificationRequests() -> [UNNotificationRequest] {
        let now = currentDate
        let season = activeBadgeSeason
        let phase = season.phase(at: now)
        var requests: [UNNotificationRequest] = []

        guard phase == .preview || phase == .active else {
            return requests
        }

        if season.openingDate > now {
            let content = UNMutableNotificationContent()
            content.title = "Jetzt Anstich!"
            content.body = "Der Berg startet jetzt für dieses Jahr. Hol dir deinen ersten Stempel."
            content.sound = .default

            if let trigger = calendarTrigger(for: season.openingDate, in: season.calendar) {
                requests.append(
                    UNNotificationRequest(
                        identifier: "bergschein.\(season.id).event-start",
                        content: content,
                        trigger: trigger
                    )
                )
            }
        }

        if stampNotificationsEnabled {
            for badge in season.badges where !unlockedBadges.contains(badge.id) {
                guard let reminderDate = notificationDate(in: season, month: badge.month, day: badge.day, hour: 19, minute: 0),
                      reminderDate > now,
                      reminderDate >= season.openingDate,
                      reminderDate < season.endDate else {
                    continue
                }

                let content = UNMutableNotificationContent()
                content.title = "Stempel für heute noch offen"
                content.body = "Hol dir den Stempel für den \(badge.name), solange der Bergtag noch läuft."
                content.sound = .default

                if let trigger = calendarTrigger(for: reminderDate, in: season.calendar) {
                    requests.append(
                        UNNotificationRequest(
                            identifier: "bergschein.\(season.id).stamp.\(badge.id)",
                            content: content,
                            trigger: trigger
                        )
                    )
                }
            }
        }

        if challengeNotificationsEnabled {
            for challenge in season.challenges where challenge.shouldScheduleNotification {
                guard let reminderDate = season.calendar.date(
                    bySettingHour: 10,
                    minute: 0,
                    second: 0,
                    of: challenge.date
                ), reminderDate > now,
                  reminderDate >= season.openingDate,
                  reminderDate < season.endDate else {
                    continue
                }

                let content = UNMutableNotificationContent()
                content.title = "Heutige Challenge"
                content.body = challengeNotificationBody(for: challenge)
                content.sound = .default
                content.userInfo = [
                    "destination": NotificationDestination.challenge.rawValue,
                    "seasonID": season.id
                ]

                if let trigger = calendarTrigger(for: reminderDate, in: season.calendar) {
                    requests.append(
                        UNNotificationRequest(
                            identifier: "bergschein.\(season.id).challenge.\(challenge.id)",
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

    func calendarTrigger(for date: Date, in calendar: Calendar) -> UNCalendarNotificationTrigger? {
        let components = calendar.dateComponents([.timeZone, .year, .month, .day, .hour, .minute], from: date)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}
