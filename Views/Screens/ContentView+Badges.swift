import SwiftUI

extension ContentView {
    var activeBadgeSeason: SeasonDefinition { SeasonCatalog.displayedSeason(at: currentDate) }
    var playableSeason: SeasonDefinition? { SeasonCatalog.playableSeason(at: currentDate) }
    var activeSeasonPhase: SeasonPhase { activeBadgeSeason.phase(at: currentDate) }
    var activeSeasonProgress: SeasonProgress { seasonProgressStore.progress(for: activeBadgeSeason.id) }
    var badgeCalendar: Calendar { activeBadgeSeason.calendar }
    var badgeDefinitions: [BadgeDefinition] { activeBadgeSeason.badges }
    var challengeDefinitions: [DailyChallenge] { activeBadgeSeason.challenges }
    var unlockedBadges: Set<String> { activeSeasonProgress.unlockedBadgeIDs.intersection(Set(badgeDefinitions.map(\.id))) }

    var canClaimToday: Bool {
        playableSeason?.id == activeBadgeSeason.id && hasOfficialOpeningStarted &&
        locationController.isInAllowedRegion && isWithinClaimWindow &&
        currentBadge != nil && !isCurrentBadgeUnlocked
    }

    var isWithinClaimWindow: Bool {
        let hour = badgeCalendar.component(.hour, from: currentDate)
        return hour >= claimStartHour && hour < claimEndHour
    }

    var claimStatusText: String {
        if activeSeasonPhase == .preparation, let next = SeasonCatalog.nextKnownSeason(after: currentDate) {
            return "Die nächste bekannte Saison ist \(next.title)."
        }
        if isShowingNextOpeningCountdown {
            return "Am \(activeBadgeSeason.openingDate.formatted(.dateTime.day().month(.wide).year().hour().minute())) ist wieder Anstich in Erlangen!"
        }
        if hasEventEnded { return "Die Stempelsaison \(activeBadgeSeason.title) ist abgeschlossen. Deine gesammelten Stempel bleiben im Bergschein erhalten." }
        if unlockedBadges.count >= badgeDefinitions.count, !badgeDefinitions.isEmpty { return "Alle \(badgeDefinitions.count) Stempel sind bereits freigeschaltet." }
        if let officialOpeningDate, currentDate < officialOpeningDate { return "Bald ist es soweit. Am \(badgeDefinitions.first?.name ?? "") \(activeBadgeSeason.title) um 17:00 Uhr ist endlich Anstich!" }
        if currentBadge == nil { return "Heute gibt es keinen Stempel mehr." }
        if !isWithinClaimWindow { return "Der Berg hat zu. Stempel können täglich nur zwischen 10:00 und 23:00 Uhr freigeschaltet werden." }
        if isCurrentBadgeUnlocked { return "Du hast dir den Stempel für heute geholt!" }
        if !locationController.isInAllowedRegion { return "Komm jetzt hoch und hol dir den Stempel für heute!" }
        return "Du bist vor Ort. Jetzt kannst du dir den Stempel für heute abholen!"
    }

    var displayedBadgeDefinitions: [BadgeDefinition] { selectedBadgeSeason.badges }
    var displayedSeasonProgress: SeasonProgress { seasonProgressStore.progress(for: selectedBadgeSeason.id) }
    var displayedUnlockedBadges: Set<String> { displayedSeasonProgress.unlockedBadgeIDs.intersection(Set(displayedBadgeDefinitions.map(\.id))) }
    var displayedHasLostLargeBergscheinChance: Bool { selectedBadgeSeason.endDate <= currentDate && displayedUnlockedBadges.count < displayedBadgeDefinitions.count }

    func displayedStandardBadges(in category: BadgeCategory) -> [BadgeDefinition] { displayedBadgeDefinitions.filter { $0.category == category && $0.subtitle == nil } }
    func displayedFeaturedBadge(in category: BadgeCategory) -> BadgeDefinition? { displayedBadgeDefinitions.first { $0.category == category && $0.subtitle != nil } }

    var currentStreak: Int {
        guard let currentBadge, let index = badgeDefinitions.firstIndex(where: { $0.id == currentBadge.id }) else { return 0 }
        var streak = 0
        for badge in badgeDefinitions[...index].reversed() {
            guard unlockedBadges.contains(badge.id) else { break }
            streak += 1
        }
        return streak
    }

    var hasLostLargeBergscheinChance: Bool { blockingMissedBadge != nil || (hasEventEnded && unlockedBadges.count < badgeDefinitions.count) }

    var blockingMissedBadge: BadgeDefinition? {
        guard let currentBadge, let currentIndex = badgeDefinitions.firstIndex(where: { $0.id == currentBadge.id }), currentIndex > 0 else { return nil }
        return badgeDefinitions[..<currentIndex].first { !unlockedBadges.contains($0.id) }
    }

    var currentBadge: BadgeDefinition? {
        guard activeSeasonPhase == .active, currentDate >= activeBadgeSeason.openingDate else { return nil }
        let startDate = badgeCalendar.startOfDay(for: activeBadgeSeason.openingDate)
        let activeDate = badgeCalendar.startOfDay(for: currentDate)
        let offset = badgeCalendar.dateComponents([.day], from: startDate, to: activeDate).day ?? -1
        guard badgeDefinitions.indices.contains(offset) else { return nil }
        return badgeDefinitions[offset]
    }

    var isCurrentBadgeUnlocked: Bool { currentBadge.map { unlockedBadges.contains($0.id) } ?? false }
    var currentBadgeLabel: String { currentBadge?.name ?? "Keiner" }
    var defaultEventStartDate: Date? { activeBadgeSeason.openingDate }
    var eventStartDate: Date? { activeBadgeSeason.openingDate }
    var officialOpeningDate: Date? { activeBadgeSeason.openingDate }
    var officialEventEndDate: Date? { activeBadgeSeason.endDate }
    var hasOfficialOpeningStarted: Bool { currentDate >= activeBadgeSeason.openingDate }
    var hasEventEnded: Bool { currentDate >= activeBadgeSeason.endDate }

    var officialOpeningCountdownText: String {
        guard let target = SeasonCatalog.nextKnownSeason(after: currentDate)?.openingDate ?? officialOpeningDate else { return "" }
        return BergscheinDateHelper.countdownText(from: currentDate, to: target, calendar: badgeCalendar)
    }

    var checkInHeadlineLabel: String {
        if isShowingNextOpeningCountdown { return "Noch bis zum Anstich \(activeBadgeSeason.title)" }
        if hasEventEnded { return "Vorbei" }
        if currentDate < activeBadgeSeason.openingDate { return "Noch" }
        return "Heute"
    }

    var checkInHeadlineValue: String {
        if isShowingNextOpeningCountdown || currentDate < activeBadgeSeason.openingDate { return officialOpeningCountdownText }
        if hasEventEnded { return "Stempelsaison \(activeBadgeSeason.title)\nabgeschlossen" }
        return currentBadge?.name ?? "Kein Stempeltag"
    }

    var isShowingNextOpeningCountdown: Bool { activeSeasonPhase == .preview }
    func ensureTestEventStartDay() {}
    var testEventStartDate: Date { activeBadgeSeason.openingDate }

    func claimBadge() async {
        guard canClaimToday, let currentBadge else { return }
        seasonProgressStore.unlockBadge(currentBadge.id, in: activeBadgeSeason.id)
        let updatedBadges = unlockedBadges.union([currentBadge.id])
        await analyticsService.track(eventType: .badgeClaimed, installID: analyticsInstallID, eventDate: currentDate, badgeCountAfterEvent: updatedBadges.count, isPerfectSoFar: isPerfectSoFar(with: updatedBadges), challengeCountAfterEvent: completedChallengesCount, seasonID: activeBadgeSeason.id)
        let missed = blockingMissedBadge != nil
        let final = currentBadge.id == badgeDefinitions.last?.id
        withAnimation(overlayPresentationAnimation) {
            activeBadgeOverlay = BadgeOverlayPresentation(badge: currentBadge, title: "Stempel geholt!", buttonTitle: "Weiter", switchesToBadgeTab: true, subtitleOverride: missed && final ? "Letzter Bergtag" : nil, messageOverride: missed ? (final ? "Stark! Du hast dir den Stempel für den letzten Bergtag geholt." : "Stark! Du hast dir den Stempel für heute geholt.") : nil)
        }
    }

    func evaluateMissedDayNotice() {
        guard let blockingMissedBadge else {
            withAnimation(overlayDismissAnimation) { activeMissedDayAlert = nil }
            dismissedMissedBadgeIdentifier = ""
            return
        }
        guard dismissedMissedBadgeIdentifier != blockingMissedBadge.id else { return }
        withAnimation(overlayPresentationAnimation) { activeMissedDayAlert = MissedDayAlertPresentation(missedBadge: blockingMissedBadge) }
    }

    func badges(in category: BadgeCategory) -> [BadgeDefinition] { badgeDefinitions.filter { $0.category == category } }
    func standardBadges(in category: BadgeCategory) -> [BadgeDefinition] { badges(in: category).filter { $0.subtitle == nil } }
    func featuredBadge(in category: BadgeCategory) -> BadgeDefinition? { badges(in: category).first { $0.subtitle != nil } }

    func resolvedImageName(for badge: BadgeDefinition) -> String? {
        guard badge.id == displayedBadgeDefinitions.last?.id, displayedHasLostLargeBergscheinChance else { return badge.imageName }
        return selectedBadgeSeason.id == "bergschein-2026" ? "badge12b" : badge.imageName
    }

    func isPerfectSoFar(with badges: Set<String>, in season: SeasonDefinition? = nil) -> Bool {
        let definitions = season?.badges ?? badgeDefinitions
        guard !definitions.isEmpty else { return true }
        let visible: [BadgeDefinition]
        if let badge = currentBadge, let index = definitions.firstIndex(where: { $0.id == badge.id }) {
            visible = Array(definitions[...index])
        } else {
            visible = definitions
        }
        return visible.allSatisfy { badges.contains($0.id) }
    }
}
