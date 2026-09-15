import SwiftUI

extension ContentView {
    // Thin view adapters keep presentation code independent from the store's
    // season and progress calculations.
    var currentDate: Date {
        get { contentStore.currentDate }
        nonmutating set { contentStore.currentDate = newValue }
    }

    var seasonProgressStore: SeasonProgressStore { contentStore.seasonProgressStore }
    var activeBadgeSeason: SeasonDefinition { contentStore.activeBadgeSeason }
    var playableSeason: SeasonDefinition? { contentStore.playableSeason }
    var activeSeasonPhase: SeasonPhase { contentStore.activeSeasonPhase }
    var activeSeasonProgress: SeasonProgress { contentStore.activeSeasonProgress }
    var badgeCalendar: Calendar { contentStore.badgeCalendar }
    var badgeDefinitions: [BadgeDefinition] { contentStore.badgeDefinitions }
    var challengeDefinitions: [DailyChallenge] { contentStore.challengeDefinitions }
    var unlockedBadges: Set<String> { contentStore.unlockedBadges }
    var canClaimToday: Bool { contentStore.canClaimToday(isInAllowedRegion: locationController.isInAllowedRegion) }
    var isWithinClaimWindow: Bool { contentStore.isWithinClaimWindow }
    var currentStreak: Int { contentStore.currentStreak }
    var hasLostLargeBergscheinChance: Bool { contentStore.hasLostLargeBergscheinChance }
    var blockingMissedBadge: BadgeDefinition? { contentStore.blockingMissedBadge }
    var currentBadge: BadgeDefinition? { contentStore.currentBadge }
    var isCurrentBadgeUnlocked: Bool { contentStore.isCurrentBadgeUnlocked }
    var hasOfficialOpeningStarted: Bool { contentStore.hasOfficialOpeningStarted }
    var hasEventEnded: Bool { contentStore.hasEventEnded }

    var claimStatusText: String {
        if activeSeasonPhase == .preparation, let next = SeasonCatalog.nextKnownSeason(after: currentDate) {
            return "Die nächste bekannte Saison ist \(next.title)."
        }
        if isShowingNextOpeningCountdown {
            return "Am \(BergscheinDateHelper.formattedEventDateTime(activeBadgeSeason.openingDate)) Uhr ist wieder Anstich in Erlangen!"
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
    var displayedSeasonProgress: SeasonProgress { seasonProgressStore.progress(for: contentStore.progressStorageSeasonID(for: selectedBadgeSeason.id)) }
    var displayedUnlockedBadges: Set<String> { contentStore.unlockedBadges(in: selectedBadgeSeason) }
    var displayedHasLostLargeBergscheinChance: Bool { contentStore.hasLostLargeBergscheinChance(in: selectedBadgeSeason) }
    func displayedStandardBadges(in category: BadgeCategory) -> [BadgeDefinition] { displayedBadgeDefinitions.filter { $0.category == category && $0.subtitle == nil } }
    func displayedFeaturedBadge(in category: BadgeCategory) -> BadgeDefinition? { displayedBadgeDefinitions.first { $0.category == category && $0.subtitle != nil } }

    var currentBadgeLabel: String { currentBadge?.name ?? "Keiner" }
    var defaultEventStartDate: Date? { activeBadgeSeason.openingDate }
    var eventStartDate: Date? { activeBadgeSeason.openingDate }
    var officialOpeningDate: Date? { activeBadgeSeason.openingDate }
    var officialEventEndDate: Date? { activeBadgeSeason.endDate }

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
        contentStore.setTestModeActive(isTestModeActive)
        guard let result = await contentStore.claimBadge(
            isInAllowedRegion: locationController.isInAllowedRegion,
            analyticsInstallID: analyticsInstallID
        ) else {
            return
        }
        withAnimation(overlayPresentationAnimation) {
            activeBadgeOverlay = BadgeOverlayPresentation(
                badge: result.badge,
                title: "Stempel geholt!",
                buttonTitle: "Weiter",
                switchesToBadgeTab: true,
                subtitleOverride: result.missedEarlierBadge && result.isFinalBadge ? "Letzter Bergtag" : nil,
                messageOverride: result.missedEarlierBadge ? (result.isFinalBadge ? "Stark! Du hast dir den Stempel für den letzten Bergtag geholt." : "Stark! Du hast dir den Stempel für heute geholt.") : nil
            )
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
        contentStore.isPerfectSoFar(with: badges, in: season)
    }
}
