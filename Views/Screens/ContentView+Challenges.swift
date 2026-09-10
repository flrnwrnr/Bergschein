import SwiftUI

extension ContentView {
    var challengeRewardsByID: [String: ChallengeReward] {
        Dictionary(uniqueKeysWithValues: activeBadgeSeason.rewards.map { ($0.id, $0) })
    }

    /// Rewards remain accessible for every archived season that earned them;
    /// the active tab adds the current season's rewards without erasing 2026.
    var unlockedChallengeRewards: [ChallengeReward] {
        SeasonCatalog.all.flatMap { season in
            let progress = seasonProgressStore.progress(for: season.id)
            return season.rewards.filter { progress.unlockedRewardIDs.contains($0.id) }
        }
    }

    func seasonID(for reward: ChallengeReward) -> String? {
        SeasonCatalog.all.first { $0.rewards.contains(where: { $0.id == reward.id }) }?.id
    }

    func isChallengeRewardRedeemed(_ reward: ChallengeReward) -> Bool {
        guard let seasonID = seasonID(for: reward) else { return false }
        return seasonProgressStore.progress(for: seasonID).redeemedRewardIDs.contains(reward.id)
    }

    func canRedeemChallengeReward(_ reward: ChallengeReward) -> Bool {
        guard !isChallengeRewardRedeemed(reward) else { return false }
        guard let seasonID = seasonID(for: reward), let season = SeasonCatalog.season(id: seasonID) else { return false }
        if let starts = reward.redemptionStartsAt?.date(in: season.calendar), currentDate < starts { return false }
        if let ends = reward.redemptionEndsAt?.date(in: season.calendar), currentDate >= ends { return false }
        return true
    }

    var completedChallenges: Set<String> {
        activeSeasonProgress.completedChallengeIDs.intersection(Set(challengeDefinitions.filter { !$0.isPlaceholder }.map(\.id)))
    }

    var challengeIntroduction: String {
        if challengePreview != nil { return "" }
        if activeSeasonPhase == .preview || challengeDefinitions.allSatisfy(\.isPlaceholder) {
            return "Die Challenges für \(activeBadgeSeason.title) werden noch vorbereitet."
        }
        return "Hier findest du an jedem Bergtag eine Challenge rund um das Thema Kirchweih und Erlangen. Du kannst nur an genau diesem Tag mitmachen und an ausgewählten Tagen eine **Belohnung** erhalten."
    }

    var completedChallengesCount: Int { challengeDefinitions.filter { completedChallenges.contains($0.id) }.count }
    var totalChallengesCount: Int { challengeDefinitions.filter { !$0.isPlaceholder }.count }

    /// Preview is display-only and is never a claim, completion or notification source.
    var challengePreview: DailyChallenge? {
        guard activeSeasonPhase == .preview else { return nil }
        return challengeDefinitions.first
    }

    var activeChallenge: DailyChallenge? {
        guard activeSeasonPhase == .active else { return nil }
        if let overnight = challengeDefinitions.first(where: { challenge in
            guard challenge.spansMidnight, let start = challenge.startDate, let end = challenge.endDate else { return false }
            return currentDate >= start && currentDate < end
        }) { return overnight }
        return challengeDefinitions.first { badgeCalendar.isDate($0.date, inSameDayAs: currentDate) }
    }

    var canCheckInForActiveChallenge: Bool {
        guard let challenge = activeChallenge else { return false }
        return !challenge.isPlaceholder && challenge.requiresLocationCheckIn && !isChallengeCompleted(challenge) &&
            isWithinChallengeWindow(challenge) && isWithinChallengeRadius(challenge)
    }

    var shouldShowChallengeButton: Bool {
        guard let challenge = activeChallenge else { return false }
        return !challenge.isPlaceholder && challenge.requiresLocationCheckIn && !isChallengeCompleted(challenge)
    }

    var activeChallengeButtonTitle: String { "Abhaken" }

    var challengeStatusText: String {
        guard let challenge = activeChallenge else { return activeSeasonPhase == .preview ? "Die nächste Challenge wird zur Saisonöffnung freigeschaltet." : "Für heute gibt es keine Challenge mehr." }
        if challenge.isPlaceholder { return "" }
        if isChallengeCompleted(challenge) { return "Challenge für heute erledigt." }
        if !challenge.requiresLocationCheckIn { return "Ort und Details werden an diesem Tag freigeschaltet." }
        if !isWithinChallengeWindow(challenge) { return "" }
        if !isWithinChallengeRadius(challenge) { return "Du musst dich für den Check-in im markierten Bereich befinden." }
        return "Du bist im Zeitfenster und am richtigen Ort. Jetzt kannst du einchecken."
    }

    var hasChallengeSeasonEnded: Bool { currentDate >= activeBadgeSeason.endDate }

    func claimActiveChallenge() async {
        guard let challenge = activeChallenge, canCheckInForActiveChallenge else { return }
        seasonProgressStore.completeChallenge(challenge.id, in: activeBadgeSeason.id)
        let updatedChallenges = completedChallenges.union([challenge.id])
        triggerSuccessHaptic()
        await analyticsService.track(eventType: .challengeCompleted, installID: analyticsInstallID, eventDate: currentDate, badgeCountAfterEvent: unlockedBadges.count, isPerfectSoFar: isPerfectSoFar(with: unlockedBadges), challengeCountAfterEvent: updatedChallenges.count, seasonID: activeBadgeSeason.id)

        if let rewardID = challenge.rewardID, let reward = activeBadgeSeason.reward(withID: rewardID), !activeSeasonProgress.unlockedRewardIDs.contains(rewardID) {
            seasonProgressStore.unlockReward(rewardID, in: activeBadgeSeason.id)
            withAnimation(overlayPresentationAnimation) { activeChallengeRewardOverlay = ChallengeRewardOverlayPresentation(reward: reward) }
        }
    }

    func redeemChallengeReward(_ reward: ChallengeReward) {
        guard let seasonID = seasonID(for: reward), canRedeemChallengeReward(reward) else { return }
        seasonProgressStore.redeemReward(reward.id, in: seasonID)
        if let url = reward.redemptionURL { openURL(url) }
        triggerSuccessHaptic()
    }

    func isChallengeCompleted(_ challenge: DailyChallenge) -> Bool { completedChallenges.contains(challenge.id) }

    func isWithinChallengeWindow(_ challenge: DailyChallenge) -> Bool {
        guard !challenge.isPlaceholder else { return false }
        guard let start = challenge.startDate, let end = challenge.endDate else { return badgeCalendar.isDate(challenge.date, inSameDayAs: currentDate) }
        return currentDate >= start && currentDate < end
    }

    func isWithinChallengeRadius(_ challenge: DailyChallenge) -> Bool {
        guard !challenge.isPlaceholder else { return false }
        guard let center = challenge.centerCoordinate, let radius = challenge.radius else { return true }
        guard let distance = locationController.distance(to: center) else { return false }
        return distance <= radius
    }

    func challengeDistanceText(for challenge: DailyChallenge) -> String? {
        guard let center = challenge.centerCoordinate else { return nil }
        if isWithinChallengeRadius(challenge) { return "Hier" }
        guard let distance = locationController.distance(to: center) else { return nil }
        return distance < 1000 ? "\(Int(distance.rounded())) m entfernt" : String(format: "%.1f km entfernt", distance / 1000)
    }

    func challengeDirectionAngle(for challenge: DailyChallenge) -> Double? {
        guard let center = challenge.centerCoordinate else { return nil }
        return locationController.directionAngle(to: center)
    }
}
