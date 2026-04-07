import SwiftUI

extension ContentView {
    var challengeReward: ChallengeReward {
        .tbBasketballDrink
    }

    var unlockedChallengeRewards: [ChallengeReward] {
        var rewards: [ChallengeReward] = []
        if tbDrinkRewardUnlocked {
            rewards.append(challengeReward)
        }
        return rewards
    }

    var isChallengeRewardRedeemed: Bool {
        tbDrinkRewardRedeemed
    }

    var completedChallenges: Set<String> {
        Set(
            completedChallengeIdentifiers
                .split(separator: ",")
                .map(String.init)
        )
    }

    var completedChallengesCount: Int {
        challengeDefinitions.filter { completedChallenges.contains($0.id) }.count
    }

    var totalChallengesCount: Int {
        challengeDefinitions.count
    }

    var activeChallenge: DailyChallenge? {
        guard let firstChallenge = challengeDefinitions.first else {
            return nil
        }

        let currentDay = Calendar.current.startOfDay(for: currentDate)
        let firstChallengeDay = Calendar.current.startOfDay(for: firstChallenge.date)

        if currentDay < firstChallengeDay {
            return firstChallenge
        }

        if let overnightChallenge = challengeDefinitions.first(where: { challenge in
            guard challenge.spansMidnight, let startDate = challenge.startDate, let endDate = challenge.endDate else {
                return false
            }

            return currentDate >= startDate && currentDate <= endDate
        }) {
            return overnightChallenge
        }

        return challengeDefinitions.first {
            Calendar.current.isDate($0.date, inSameDayAs: currentDate)
        }
    }

    var canCheckInForActiveChallenge: Bool {
        guard let activeChallenge else {
            return false
        }

        guard activeChallenge.requiresLocationCheckIn,
              Calendar.current.isDate(activeChallenge.date, inSameDayAs: currentDate),
              !isChallengeCompleted(activeChallenge),
              isWithinChallengeWindow(activeChallenge),
              isWithinChallengeRadius(activeChallenge) else {
            return false
        }

        return true
    }

    var shouldShowChallengeButton: Bool {
        guard let activeChallenge else {
            return false
        }

        return activeChallenge.requiresLocationCheckIn && !isChallengeCompleted(activeChallenge)
    }

    var activeChallengeButtonTitle: String {
        "Abhaken"
    }

    var challengeStatusText: String {
        guard let activeChallenge else {
            return "Für heute gibt es keine Challenge mehr."
        }

        if isChallengeCompleted(activeChallenge) {
            return "Challenge für heute erledigt."
        }

        let currentDay = Calendar.current.startOfDay(for: currentDate)
        let challengeDay = Calendar.current.startOfDay(for: activeChallenge.date)

        if currentDay < challengeDay {
            return ""
        }

        if !activeChallenge.requiresLocationCheckIn {
            return "Ort und Details werden an diesem Tag freigeschaltet."
        }

        if !isWithinChallengeWindow(activeChallenge) {
            return ""
        }

        if !isWithinChallengeRadius(activeChallenge) {
            return "Du musst dich für den Check-in im markierten Bereich befinden."
        }

        return "Du bist im Zeitfenster und am richtigen Ort. Jetzt kannst du einchecken."
    }

    var hasChallengeSeasonEnded: Bool {
        guard let eventStartDate else {
            return false
        }

        var components = Calendar.current.dateComponents([.year], from: eventStartDate)
        components.month = 6
        components.day = 2

        guard let challengeEndDate = Calendar.current.date(from: components) else {
            return false
        }

        return currentDate >= Calendar.current.startOfDay(for: challengeEndDate)
    }

    func claimActiveChallenge() {
        guard let activeChallenge, canCheckInForActiveChallenge else {
            return
        }

        var updatedChallenges = completedChallenges
        updatedChallenges.insert(activeChallenge.id)
        completedChallengeIdentifiers = updatedChallenges.sorted().joined(separator: ",")
        triggerSuccessHaptic()

        let badgeCountAfterEvent = unlockedBadges.count
        let perfectSoFar = isPerfectSoFar(with: unlockedBadges)
        let challengeCountAfterEvent = updatedChallenges.count
        let installID = analyticsInstallID
        let eventDate = currentDate
        Task {
            await analyticsService.track(
                eventType: .challengeCompleted,
                installID: installID,
                eventDate: eventDate,
                badgeCountAfterEvent: badgeCountAfterEvent,
                isPerfectSoFar: perfectSoFar,
                challengeCountAfterEvent: challengeCountAfterEvent
            )
        }

        if activeChallenge.id == "2026-05-23" && !tbDrinkRewardUnlocked {
            tbDrinkRewardUnlocked = true
            tbDrinkRewardRedeemed = false
            withAnimation(overlayPresentationAnimation) {
                activeChallengeRewardOverlay = ChallengeRewardOverlayPresentation(reward: challengeReward)
            }
        }
    }

    func redeemChallengeReward() {
        guard tbDrinkRewardUnlocked, !tbDrinkRewardRedeemed else {
            return
        }

        tbDrinkRewardRedeemed = true
        triggerSuccessHaptic()
    }

    func isChallengeCompleted(_ challenge: DailyChallenge) -> Bool {
        completedChallenges.contains(challenge.id)
    }

    func isWithinChallengeWindow(_ challenge: DailyChallenge) -> Bool {
        if isTestModeActive {
            return true
        }

        guard let startDate = challenge.startDate, let endDate = challenge.endDate else {
            return Calendar.current.isDate(challenge.date, inSameDayAs: currentDate)
        }

        return currentDate >= startDate && currentDate <= endDate
    }

    func isWithinChallengeRadius(_ challenge: DailyChallenge) -> Bool {
        if isTestModeActive {
            return true
        }

        guard let center = challenge.centerCoordinate, let radius = challenge.radius else {
            return true
        }

        guard let distance = locationController.distance(to: center) else {
            return false
        }

        return distance <= radius
    }

    func challengeDistanceText(for challenge: DailyChallenge) -> String? {
        guard let center = challenge.centerCoordinate else {
            return nil
        }

        if isWithinChallengeRadius(challenge) {
            return "Hier"
        }

        guard let distance = locationController.distance(to: center) else {
            return nil
        }

        if distance < 1000 {
            return "\(Int(distance.rounded())) m entfernt"
        }

        return String(format: "%.1f km entfernt", distance / 1000)
    }

    func challengeDirectionAngle(for challenge: DailyChallenge) -> Double? {
        guard let center = challenge.centerCoordinate else {
            return nil
        }

        return locationController.directionAngle(to: center)
    }
}
