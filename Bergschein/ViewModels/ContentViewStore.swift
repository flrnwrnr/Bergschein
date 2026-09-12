import Combine
import Foundation

@MainActor
final class ContentViewStore: ObservableObject {
    struct AnalyticsTrackingEvent: Sendable {
        let eventType: AnalyticsEventType
        let installID: String
        let eventDate: Date
        let badgeCountAfterEvent: Int
        let isPerfectSoFar: Bool
        let challengeCountAfterEvent: Int
        let seasonID: String
    }

    typealias AnalyticsTracker = @Sendable (AnalyticsTrackingEvent) async -> Void

    struct BadgeClaimResult {
        let badge: BadgeDefinition
        let missedEarlierBadge: Bool
        let isFinalBadge: Bool
    }

    struct ChallengeClaimResult {
        let unlockedReward: ChallengeReward?
    }

    struct ChallengeRewardRedemptionResult {
        let destinationURL: URL?
    }

    let seasonProgressStore: SeasonProgressStore
    private let now: () -> Date
    private let analyticsTracker: AnalyticsTracker
    private var progressObservation: AnyCancellable?

    @Published var currentDate: Date
    @Published private(set) var isTestModeActive = false

    init(
        seasonProgressStore: SeasonProgressStore? = nil,
        now: @escaping () -> Date = Date.init,
        analyticsService: AnalyticsService = .shared,
        analyticsTracker: AnalyticsTracker? = nil
    ) {
        self.seasonProgressStore = seasonProgressStore ?? SeasonProgressStore()
        self.now = now
        if let analyticsTracker {
            self.analyticsTracker = analyticsTracker
        } else {
            self.analyticsTracker = { event in
                await analyticsService.track(
                    eventType: event.eventType,
                    installID: event.installID,
                    eventDate: event.eventDate,
                    badgeCountAfterEvent: event.badgeCountAfterEvent,
                    isPerfectSoFar: event.isPerfectSoFar,
                    challengeCountAfterEvent: event.challengeCountAfterEvent,
                    seasonID: event.seasonID
                )
            }
        }
        currentDate = now()
        progressObservation = self.seasonProgressStore.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func syncCurrentDate() {
        currentDate = now()
    }

    var activeBadgeSeason: SeasonDefinition {
        SeasonCatalog.displayedSeason(at: currentDate)
    }

    var playableSeason: SeasonDefinition? {
        SeasonCatalog.playableSeason(at: currentDate)
    }

    var activeSeasonPhase: SeasonPhase {
        activeBadgeSeason.phase(at: currentDate)
    }

    var activeSeasonProgress: SeasonProgress {
        seasonProgressStore.progress(for: communitySeasonID)
    }

    var communitySeasonID: String {
        progressStorageSeasonID(for: activeBadgeSeason.id)
    }

    func progressStorageSeasonID(for seasonID: String) -> String {
        SeasonProgressStore.storageSeasonID(for: seasonID, isTestMode: isTestModeActive)
    }

    func setTestModeActive(_ isActive: Bool) {
        guard isTestModeActive != isActive else { return }
        isTestModeActive = isActive
    }

    var badgeCalendar: Calendar {
        activeBadgeSeason.calendar
    }

    var badgeDefinitions: [BadgeDefinition] {
        activeBadgeSeason.badges
    }

    var challengeDefinitions: [DailyChallenge] {
        activeBadgeSeason.challenges
    }

    var unlockedBadges: Set<String> {
        unlockedBadges(in: activeBadgeSeason)
    }

    func unlockedBadges(in season: SeasonDefinition) -> Set<String> {
        seasonProgressStore.progress(for: progressStorageSeasonID(for: season.id))
            .unlockedBadgeIDs.intersection(Set(season.badges.map(\.id)))
    }

    func hasLostLargeBergscheinChance(in season: SeasonDefinition) -> Bool {
        season.endDate <= currentDate && unlockedBadges(in: season).count < season.badges.count
    }

    var currentBadge: BadgeDefinition? {
        guard activeSeasonPhase == .active, currentDate >= activeBadgeSeason.openingDate else {
            return nil
        }
        let startDate = badgeCalendar.startOfDay(for: activeBadgeSeason.openingDate)
        let activeDate = badgeCalendar.startOfDay(for: currentDate)
        let offset = badgeCalendar.dateComponents([.day], from: startDate, to: activeDate).day ?? -1
        guard badgeDefinitions.indices.contains(offset) else {
            return nil
        }
        return badgeDefinitions[offset]
    }

    var isCurrentBadgeUnlocked: Bool {
        currentBadge.map { unlockedBadges.contains($0.id) } ?? false
    }

    var hasOfficialOpeningStarted: Bool {
        currentDate >= activeBadgeSeason.openingDate
    }

    var hasEventEnded: Bool {
        currentDate >= activeBadgeSeason.endDate
    }

    var isWithinClaimWindow: Bool {
        let hour = badgeCalendar.component(.hour, from: currentDate)
        return hour >= 10 && hour < 23
    }

    func canClaimToday(isInAllowedRegion: Bool) -> Bool {
        playableSeason?.id == activeBadgeSeason.id && hasOfficialOpeningStarted &&
            isInAllowedRegion && isWithinClaimWindow &&
            currentBadge != nil && !isCurrentBadgeUnlocked
    }

    var blockingMissedBadge: BadgeDefinition? {
        guard let currentBadge,
              let currentIndex = badgeDefinitions.firstIndex(where: { $0.id == currentBadge.id }),
              currentIndex > 0 else {
            return nil
        }
        return badgeDefinitions[..<currentIndex].first { !unlockedBadges.contains($0.id) }
    }

    var currentStreak: Int {
        guard let currentBadge,
              let index = badgeDefinitions.firstIndex(where: { $0.id == currentBadge.id }) else {
            return 0
        }
        var streak = 0
        for badge in badgeDefinitions[...index].reversed() {
            guard unlockedBadges.contains(badge.id) else {
                break
            }
            streak += 1
        }
        return streak
    }

    var hasLostLargeBergscheinChance: Bool {
        blockingMissedBadge != nil || (hasEventEnded && unlockedBadges.count < badgeDefinitions.count)
    }

    var completedChallenges: Set<String> {
        activeSeasonProgress.completedChallengeIDs.intersection(
            Set(challengeDefinitions.filter { !$0.isPlaceholder }.map(\.id))
        )
    }

    var completedChallengesCount: Int {
        challengeDefinitions.filter { completedChallenges.contains($0.id) }.count
    }

    var challengeRewardsByID: [String: ChallengeReward] {
        Dictionary(uniqueKeysWithValues: activeBadgeSeason.rewards.map { ($0.id, $0) })
    }

    var unlockedChallengeRewardGroups: [ChallengeRewardSeasonGroup] {
        ChallengeRewardSeasonGroup.unlocked(in: SeasonCatalog.all) {
            seasonProgressStore.progress(for: progressStorageSeasonID(for: $0))
        }
    }

    var activeChallenge: DailyChallenge? {
        guard activeSeasonPhase == .active else {
            return nil
        }
        if let overnight = challengeDefinitions.first(where: { challenge in
            guard challenge.spansMidnight,
                  let start = challenge.startDate(in: badgeCalendar),
                  let end = challenge.endDate(in: badgeCalendar) else {
                return false
            }
            return currentDate >= start && currentDate < end
        }) {
            return overnight
        }
        return challengeDefinitions.first {
            badgeCalendar.isDate($0.date(in: badgeCalendar), inSameDayAs: currentDate)
        }
    }

    func isWithinChallengeWindow(_ challenge: DailyChallenge) -> Bool {
        guard !challenge.isPlaceholder else {
            return false
        }
        guard let start = challenge.startDate(in: badgeCalendar),
              let end = challenge.endDate(in: badgeCalendar) else {
            return badgeCalendar.isDate(challenge.date(in: badgeCalendar), inSameDayAs: currentDate)
        }
        return currentDate >= start && currentDate < end
    }

    func canCheckInForActiveChallenge(isWithinRadius: (DailyChallenge) -> Bool) -> Bool {
        guard let challenge = activeChallenge else {
            return false
        }
        return !challenge.isPlaceholder && challenge.requiresLocationCheckIn &&
            !completedChallenges.contains(challenge.id) && isWithinChallengeWindow(challenge) &&
            isWithinRadius(challenge)
    }

    func seasonID(for reward: ChallengeReward) -> String? {
        SeasonCatalog.all.first { $0.rewards.contains(where: { $0.id == reward.id }) }?.id
    }

    func isChallengeRewardRedeemed(_ reward: ChallengeReward) -> Bool {
        guard let seasonID = seasonID(for: reward) else {
            return false
        }
        return seasonProgressStore.progress(for: progressStorageSeasonID(for: seasonID))
            .redeemedRewardIDs.contains(reward.id)
    }

    func canRedeemChallengeReward(_ reward: ChallengeReward) -> Bool {
        guard !isChallengeRewardRedeemed(reward),
              let seasonID = seasonID(for: reward),
              let season = SeasonCatalog.season(id: seasonID) else {
            return false
        }
        if let starts = reward.redemptionStartsAt?.date(in: season.calendar), currentDate < starts {
            return false
        }
        if let ends = reward.redemptionEndsAt?.date(in: season.calendar), currentDate >= ends {
            return false
        }
        return true
    }

    func claimBadge(
        isInAllowedRegion: Bool,
        analyticsInstallID: String
    ) async -> BadgeClaimResult? {
        guard canClaimToday(isInAllowedRegion: isInAllowedRegion), let badge = currentBadge else {
            return nil
        }

        let season = activeBadgeSeason
        let eventDate = currentDate
        let updatedBadges = unlockedBadges.union([badge.id])
        let updatedChallengeCount = completedChallengesCount
        let missedEarlierBadge = blockingMissedBadge != nil
        let isFinalBadge = badge.id == badgeDefinitions.last?.id
        let isPerfect = isPerfectSoFar(with: updatedBadges, in: season)

        let storageSeasonID = progressStorageSeasonID(for: season.id)
        seasonProgressStore.unlockBadge(badge.id, in: storageSeasonID)
        await analyticsTracker(AnalyticsTrackingEvent(
            eventType: .badgeClaimed,
            installID: analyticsInstallID,
            eventDate: eventDate,
            badgeCountAfterEvent: updatedBadges.count,
            isPerfectSoFar: isPerfect,
            challengeCountAfterEvent: updatedChallengeCount,
            seasonID: storageSeasonID
        ))
        return BadgeClaimResult(
            badge: badge,
            missedEarlierBadge: missedEarlierBadge,
            isFinalBadge: isFinalBadge
        )
    }

    func claimActiveChallenge(
        isWithinRadius: (DailyChallenge) -> Bool,
        analyticsInstallID: String,
        onClaimAccepted: @MainActor () -> Void
    ) async -> ChallengeClaimResult? {
        guard let challenge = activeChallenge,
              canCheckInForActiveChallenge(isWithinRadius: isWithinRadius) else {
            return nil
        }

        let season = activeBadgeSeason
        let eventDate = currentDate
        let updatedChallenges = completedChallenges.union([challenge.id])
        let badgeCount = unlockedBadges.count
        let isPerfect = isPerfectSoFar(with: unlockedBadges, in: season)
        let reward = challenge.rewardID.flatMap { season.reward(withID: $0) }
        let unlockedReward = reward.flatMap { reward in
            activeSeasonProgress.unlockedRewardIDs.contains(reward.id) ? nil : reward
        }

        let storageSeasonID = progressStorageSeasonID(for: season.id)
        seasonProgressStore.completeChallenge(challenge.id, in: storageSeasonID)
        if let unlockedReward {
            seasonProgressStore.unlockReward(unlockedReward.id, in: storageSeasonID)
        }
        onClaimAccepted()
        await analyticsTracker(AnalyticsTrackingEvent(
            eventType: .challengeCompleted,
            installID: analyticsInstallID,
            eventDate: eventDate,
            badgeCountAfterEvent: badgeCount,
            isPerfectSoFar: isPerfect,
            challengeCountAfterEvent: updatedChallenges.count,
            seasonID: storageSeasonID
        ))
        return ChallengeClaimResult(unlockedReward: unlockedReward)
    }

    func redeemChallengeReward(_ reward: ChallengeReward) -> ChallengeRewardRedemptionResult? {
        guard let seasonID = seasonID(for: reward), canRedeemChallengeReward(reward) else {
            return nil
        }
        seasonProgressStore.redeemReward(reward.id, in: progressStorageSeasonID(for: seasonID))
        return ChallengeRewardRedemptionResult(destinationURL: reward.redemptionURL)
    }

    func isPerfectSoFar(with badges: Set<String>, in season: SeasonDefinition? = nil) -> Bool {
        let definitions = season?.badges ?? badgeDefinitions
        guard !definitions.isEmpty else {
            return true
        }
        let visible: [BadgeDefinition]
        if let badge = currentBadge,
           let index = definitions.firstIndex(where: { $0.id == badge.id }) {
            visible = Array(definitions[...index])
        } else {
            visible = definitions
        }
        return visible.allSatisfy { badges.contains($0.id) }
    }
}
