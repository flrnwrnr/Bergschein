import SwiftUI

extension ContentView {
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var canClaimToday: Bool {
        !hasEventEnded &&
        hasOfficialOpeningStarted &&
        locationController.isInAllowedRegion &&
        isWithinClaimWindow &&
        currentBadge != nil &&
        !isCurrentBadgeUnlocked
    }

    var isWithinClaimWindow: Bool {
        let hour = Calendar.current.component(.hour, from: currentDate)
        return hour >= claimStartHour && hour < claimEndHour
    }

    var claimStatusText: String {
        if hasEventEnded {
            return "Der Berg ist für dieses Jahr vorbei. Danke fürs Mitstempeln und bis zum nächsten Berg!"
        }
        if unlockedBadges.count >= badgeDefinitions.count {
            return "Alle 12 Stempel sind bereits freigeschaltet."
        }
        if let officialOpeningDate, currentDate < officialOpeningDate {
            return "Bald ist es soweit. Am 21.05.2026 um 17:00 Uhr ist endlich Anstich!"
        }
        if currentBadge == nil {
            return "Heute gibt es keinen Stempel mehr."
        }
        if !isWithinClaimWindow {
            return "Der Berg hat zu. Stempel können täglich nur zwischen 10:00 und 23:00 Uhr freigeschaltet werden."
        }
        if isCurrentBadgeUnlocked {
            return "Du hast dir den Stempel für heute geholt!"
        }
        if !locationController.isInAllowedRegion {
            return "Komm jetzt hoch und hol dir den Stempel für heute!"
        }
        if currentBadge != nil {
            return "Du bist vor Ort. Jetzt kannst du dir den Stempel für heute abholen!"
        }
        return "Heute ist kein Stempel verfügbar."
    }

    var unlockedBadges: Set<String> {
        Set(
            unlockedBadgeIdentifiers
                .split(separator: ",")
                .map(String.init)
        )
    }

    var currentStreak: Int {
        let currentBadgeIndex = currentBadge.flatMap { badge in
            badgeDefinitions.firstIndex(where: { $0.id == badge.id })
        }
        let anchorIndex = {
            if let currentBadgeIndex {
                let currentBadge = badgeDefinitions[currentBadgeIndex]
                if unlockedBadges.contains(currentBadge.id) {
                    return currentBadgeIndex
                }
                return max(currentBadgeIndex - 1, 0)
            }
            return badgeDefinitions.indices.last ?? 0
        }()

        guard badgeDefinitions.indices.contains(anchorIndex) else {
            return 0
        }

        var streak = 0
        for index in stride(from: anchorIndex, through: 0, by: -1) {
            let badge = badgeDefinitions[index]
            if unlockedBadges.contains(badge.id) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    var blockingMissedBadge: BadgeDefinition? {
        guard let currentBadgeIndex = currentBadge.flatMap({ badge in
            badgeDefinitions.firstIndex(where: { $0.id == badge.id })
        }) else {
            return nil
        }

        guard currentBadgeIndex > 0 else {
            return nil
        }

        for index in 0..<currentBadgeIndex {
            let badge = badgeDefinitions[index]
            if !unlockedBadges.contains(badge.id) {
                return badge
            }
        }

        return nil
    }

    var currentBadge: BadgeDefinition? {
        guard let eventStartDate else {
            return nil
        }

        if hasEventEnded {
            return nil
        }

        if let officialOpeningDate, currentDate < officialOpeningDate {
            return nil
        }

        let startDate = Calendar.current.startOfDay(for: eventStartDate)
        let activeDate = Calendar.current.startOfDay(for: currentDate)
        let dayOffset = Calendar.current.dateComponents([.day], from: startDate, to: activeDate).day ?? -1

        guard badgeDefinitions.indices.contains(dayOffset) else {
            return nil
        }

        return badgeDefinitions[dayOffset]
    }

    var isCurrentBadgeUnlocked: Bool {
        guard let currentBadge else {
            return false
        }
        return unlockedBadges.contains(currentBadge.id)
    }

    var currentBadgeLabel: String {
        currentBadge?.name ?? "Keiner"
    }

    var defaultEventStartDate: Date? {
        var components = Calendar.current.dateComponents([.year], from: currentDate)
        components.month = 5
        components.day = 21
        guard let eventDate = Calendar.current.date(from: components) else {
            return nil
        }
        return Calendar.current.startOfDay(for: eventDate)
    }

    var eventStartDate: Date? {
        if !useSimulatedDate {
            return defaultEventStartDate
        }

        if testEventStartDay.isEmpty {
            return defaultEventStartDate
        }

        return Self.dayFormatter.date(from: testEventStartDay) ?? defaultEventStartDate
    }

    var officialOpeningDate: Date? {
        guard let eventStartDate else {
            return nil
        }

        return Calendar.current.date(
            bySettingHour: 17,
            minute: 0,
            second: 0,
            of: eventStartDate
        )
    }

    var officialEventEndDate: Date? {
        guard let eventStartDate else {
            return nil
        }

        guard let juneFirst = Calendar.current.date(byAdding: .day, value: badgeDefinitions.count - 1, to: eventStartDate) else {
            return nil
        }

        return Calendar.current.date(
            bySettingHour: 23,
            minute: 0,
            second: 0,
            of: juneFirst
        )
    }

    var hasOfficialOpeningStarted: Bool {
        guard let officialOpeningDate else {
            return false
        }

        return currentDate >= officialOpeningDate
    }

    var hasEventEnded: Bool {
        guard let officialEventEndDate else {
            return false
        }

        return currentDate >= officialEventEndDate
    }

    var officialOpeningCountdownText: String {
        guard let officialOpeningDate else {
            return ""
        }

        return BergscheinDateHelper.countdownText(from: currentDate, to: officialOpeningDate)
    }

    var checkInHeadlineLabel: String {
        if hasEventEnded {
            return "Vorbei"
        }
        if let officialOpeningDate, currentDate < officialOpeningDate {
            return "Noch"
        }

        return "Heute"
    }

    var checkInHeadlineValue: String {
        if hasEventEnded {
            return "Das war's\nfür dieses Jahr"
        }
        if let officialOpeningDate, currentDate < officialOpeningDate {
            return officialOpeningCountdownText
        }

        return currentBadge?.name ?? "Kein Stempeltag"
    }

    func ensureTestEventStartDay() {
        guard testEventStartDay.isEmpty else {
            return
        }
        testEventStartDay = Self.dayFormatter.string(from: defaultEventStartDate ?? Calendar.current.startOfDay(for: Date()))
    }

    func claimBadge() {
        guard canClaimToday, let currentBadge else {
            return
        }

        var updatedBadges = unlockedBadges
        updatedBadges.insert(currentBadge.id)
        unlockedBadgeIdentifiers = updatedBadges.sorted().joined(separator: ",")

        let badgeCountAfterEvent = updatedBadges.count
        let perfectSoFar = isPerfectSoFar(with: updatedBadges)
        let challengeCountAfterEvent = completedChallengesCount
        let installID = analyticsInstallID
        let eventDate = currentDate
        Task {
            await analyticsService.track(
                eventType: .badgeClaimed,
                installID: installID,
                eventDate: eventDate,
                badgeCountAfterEvent: badgeCountAfterEvent,
                isPerfectSoFar: perfectSoFar,
                challengeCountAfterEvent: challengeCountAfterEvent
            )
        }

        let hasMissedDay = blockingMissedBadge != nil
        let isFinalDayBadge = currentBadge.id == "06-01"
        let subtitleOverride: String? = hasMissedDay && isFinalDayBadge ? "Letzter Bergtag" : nil
        let messageOverride: String? = {
            guard hasMissedDay else {
                return nil
            }
            if isFinalDayBadge {
                return "Stark! Du hast dir den Stempel für den letzten Bergtag geholt."
            }
            return "Stark! Du hast dir den Stempel für heute geholt."
        }()

        withAnimation(overlayPresentationAnimation) {
            activeBadgeOverlay = BadgeOverlayPresentation(
                badge: currentBadge,
                title: "Stempel geholt!",
                buttonTitle: "Weiter",
                switchesToBadgeTab: true,
                subtitleOverride: subtitleOverride,
                messageOverride: messageOverride
            )
        }
    }

    func evaluateMissedDayNotice() {
        guard let blockingMissedBadge else {
            withAnimation(overlayDismissAnimation) {
                activeMissedDayAlert = nil
            }
            dismissedMissedBadgeIdentifier = ""
            return
        }

        guard dismissedMissedBadgeIdentifier != blockingMissedBadge.id else {
            return
        }

        withAnimation(overlayPresentationAnimation) {
            activeMissedDayAlert = MissedDayAlertPresentation(missedBadge: blockingMissedBadge)
        }
    }

    func badges(in category: BadgeCategory) -> [BadgeDefinition] {
        badgeDefinitions.filter { $0.category == category }
    }

    func standardBadges(in category: BadgeCategory) -> [BadgeDefinition] {
        let badges = badges(in: category)
        guard category == .profi, let lastBadge = badges.last, lastBadge.subtitle != nil else {
            return badges
        }
        return Array(badges.dropLast())
    }

    func featuredBadge(in category: BadgeCategory) -> BadgeDefinition? {
        let badges = badges(in: category)
        guard category == .profi, let lastBadge = badges.last, lastBadge.subtitle != nil else {
            return nil
        }
        return lastBadge
    }

    func resolvedImageName(for badge: BadgeDefinition) -> String? {
        if badge.id == "06-01", blockingMissedBadge != nil {
            return "badge12b"
        }
        return badge.imageName
    }

    func isPerfectSoFar(with badges: Set<String>) -> Bool {
        guard !badgeDefinitions.isEmpty else {
            return true
        }

        let currentBadgeIndex = currentBadge.flatMap { badge in
            badgeDefinitions.firstIndex(where: { $0.id == badge.id })
        }

        let anchorIndex: Int
        if let currentBadgeIndex {
            let todayBadge = badgeDefinitions[currentBadgeIndex]
            if badges.contains(todayBadge.id) {
                anchorIndex = currentBadgeIndex
            } else {
                anchorIndex = max(currentBadgeIndex - 1, 0)
            }
        } else {
            anchorIndex = badgeDefinitions.count - 1
        }

        guard anchorIndex >= 0 else {
            return true
        }

        for index in 0...anchorIndex {
            if !badges.contains(badgeDefinitions[index].id) {
                return false
            }
        }
        return true
    }
}
