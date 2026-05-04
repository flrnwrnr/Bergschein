import SwiftUI

extension ContentView {
    var challengeRewardsByID: [String: ChallengeReward] {
        [
            ChallengeReward.zirkelFreeEntry.id: .zirkelFreeEntry,
            ChallengeReward.tbBasketballDrink.id: .tbBasketballDrink,
            ChallengeReward.bibOfferCode.id: .bibOfferCode,
        ]
    }

    var unlockedChallengeRewards: [ChallengeReward] {
        var rewards: [ChallengeReward] = []
        if zirkelRewardUnlocked {
            rewards.append(.zirkelFreeEntry)
        }
        if tbDrinkRewardUnlocked {
            rewards.append(.tbBasketballDrink)
        }
        if bibOfferRewardUnlocked {
            rewards.append(.bibOfferCode)
        }
        return rewards
    }

    func isChallengeRewardRedeemed(_ reward: ChallengeReward) -> Bool {
        switch reward.id {
        case ChallengeReward.zirkelFreeEntry.id:
            return zirkelRewardRedeemed
        case ChallengeReward.tbBasketballDrink.id:
            return tbDrinkRewardRedeemed
        case ChallengeReward.bibOfferCode.id:
            return bibOfferRewardRedeemed
        default:
            return false
        }
    }

    func canRedeemChallengeReward(_ reward: ChallengeReward) -> Bool {
        if reward.id == ChallengeReward.zirkelFreeEntry.id {
            let components = Calendar.current.dateComponents([.year, .month], from: currentDate)
            guard components.year == 2026, let month = components.month else {
                return false
            }
            return month == 6 || month == 7
        }
        return true
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

        if activeChallenge.id == "2026-05-25" && !tbDrinkRewardUnlocked {
            tbDrinkRewardUnlocked = true
            tbDrinkRewardRedeemed = false
            withAnimation(overlayPresentationAnimation) {
                activeChallengeRewardOverlay = ChallengeRewardOverlayPresentation(reward: .tbBasketballDrink)
            }
        }

        if activeChallenge.id == "2026-05-22" && !zirkelRewardUnlocked {
            zirkelRewardUnlocked = true
            zirkelRewardRedeemed = false
            withAnimation(overlayPresentationAnimation) {
                activeChallengeRewardOverlay = ChallengeRewardOverlayPresentation(reward: .zirkelFreeEntry)
            }
        }

        if activeChallenge.id == "2026-05-29" && !bibOfferRewardUnlocked {
            bibOfferRewardUnlocked = true
            bibOfferRewardRedeemed = false
            withAnimation(overlayPresentationAnimation) {
                activeChallengeRewardOverlay = ChallengeRewardOverlayPresentation(reward: .bibOfferCode)
            }
        }
    }

    func redeemChallengeReward(_ reward: ChallengeReward) {
        switch reward.id {
        case ChallengeReward.zirkelFreeEntry.id:
            guard zirkelRewardUnlocked, !zirkelRewardRedeemed, canRedeemChallengeReward(reward) else {
                return
            }
            zirkelRewardRedeemed = true
        case ChallengeReward.tbBasketballDrink.id:
            guard tbDrinkRewardUnlocked, !tbDrinkRewardRedeemed else {
                return
            }
            tbDrinkRewardRedeemed = true
        case ChallengeReward.bibOfferCode.id:
            guard bibOfferRewardUnlocked, !bibOfferRewardRedeemed else {
                return
            }
            bibOfferRewardRedeemed = true
            if let redeemURL = URL(string: "https://apps.apple.com/redeem?ctx=offercodes&id=6752996931&code=BERGSCHEIN") {
                openURL(redeemURL)
            }
        default:
            return
        }

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
