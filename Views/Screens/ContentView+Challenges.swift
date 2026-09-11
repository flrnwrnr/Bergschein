import SwiftUI

extension ContentView {
    var challengeRewardsByID: [String: ChallengeReward] { contentStore.challengeRewardsByID }
    var unlockedChallengeRewardGroups: [ChallengeRewardSeasonGroup] { contentStore.unlockedChallengeRewardGroups }
    func seasonID(for reward: ChallengeReward) -> String? { contentStore.seasonID(for: reward) }
    func isChallengeRewardRedeemed(_ reward: ChallengeReward) -> Bool { contentStore.isChallengeRewardRedeemed(reward) }
    func canRedeemChallengeReward(_ reward: ChallengeReward) -> Bool { contentStore.canRedeemChallengeReward(reward) }
    var completedChallenges: Set<String> { contentStore.completedChallenges }

    var challengeIntroduction: String {
        if challengePreview != nil { return "" }
        if activeSeasonPhase == .preview || challengeDefinitions.allSatisfy(\.isPlaceholder) {
            return "Die Challenges für \(activeBadgeSeason.title) werden noch vorbereitet."
        }
        return "Hier findest du an jedem Bergtag eine Challenge rund um das Thema Kirchweih und Erlangen. Du kannst nur an genau diesem Tag mitmachen und an ausgewählten Tagen eine **Belohnung** erhalten."
    }

    var completedChallengesCount: Int { contentStore.completedChallengesCount }
    var totalChallengesCount: Int { challengeDefinitions.filter { !$0.isPlaceholder }.count }

    /// Preview is display-only and is never a claim, completion or notification source.
    var challengePreview: DailyChallenge? {
        guard activeSeasonPhase == .preview else { return nil }
        return challengeDefinitions.first
    }

    var activeChallenge: DailyChallenge? { contentStore.activeChallenge }

    var canCheckInForActiveChallenge: Bool {
        contentStore.canCheckInForActiveChallenge(isWithinRadius: isWithinChallengeRadius(_:))
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
        guard let result = await contentStore.claimActiveChallenge(
            isWithinRadius: isWithinChallengeRadius(_:),
            analyticsInstallID: analyticsInstallID,
            onClaimAccepted: triggerSuccessHaptic
        ) else {
            return
        }
        if let reward = result.unlockedReward {
            withAnimation(overlayPresentationAnimation) {
                activeChallengeRewardOverlay = ChallengeRewardOverlayPresentation(reward: reward)
            }
        }
    }

    func redeemChallengeReward(_ reward: ChallengeReward) {
        guard let result = contentStore.redeemChallengeReward(reward) else { return }
        if let url = result.destinationURL {
            openURL(url)
        }
        triggerSuccessHaptic()
    }

    func isChallengeCompleted(_ challenge: DailyChallenge) -> Bool { completedChallenges.contains(challenge.id) }
    func isWithinChallengeWindow(_ challenge: DailyChallenge) -> Bool { contentStore.isWithinChallengeWindow(challenge) }

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
