import Combine
import Foundation

struct SeasonProgress: Codable, Equatable {
    var unlockedBadgeIDs: Set<String> = []
    var completedChallengeIDs: Set<String> = []
    var unlockedRewardIDs: Set<String> = []
    var redeemedRewardIDs: Set<String> = []
    var raffle: SeasonRaffleProgress = .init()
}

struct SeasonRaffleProgress: Codable, Equatable {
    var hasJoined = false
    var consentTimestamp = ""
    var contactEmail = ""
    var contactName = ""
}

/// Keeps all event-specific state under stable season IDs. The migration is
/// additive and leaves legacy keys untouched as a recoverable backup.
final class SeasonProgressStore: ObservableObject {
    static let storageKey = "seasonProgressV1"
    static let migrationKey = "seasonProgressMigrationV1"
    static let testProgressMigrationKey = "seasonProgressTestSeparationV1"
    static let testSeasonPrefix = "test-"
    @Published private(set) var progressBySeasonID: [String: SeasonProgress]

    private let defaults: UserDefaults
    private let storageIsReadable: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        switch Self.load(from: defaults) {
        case .missing:
            progressBySeasonID = [:]
            storageIsReadable = true
        case let .valid(progress):
            progressBySeasonID = progress
            storageIsReadable = true
        case .invalid:
            progressBySeasonID = [:]
            storageIsReadable = false
            #if DEBUG
            print("Season progress could not be decoded; preserving the existing data.")
            #endif
        }

        if storageIsReadable {
            migrateLegacyValuesIfNeeded()
            migrateConfirmedPreReleaseTestProgressIfNeeded()
        }
    }

    static func storageSeasonID(for seasonID: String, isTestMode: Bool) -> String {
        isTestMode ? testSeasonPrefix + seasonID : seasonID
    }

    func progress(for seasonID: String) -> SeasonProgress {
        progressBySeasonID[seasonID] ?? SeasonProgress()
    }

    func unlockBadge(_ badgeID: String, in seasonID: String) {
        update(seasonID) { $0.unlockedBadgeIDs.insert(badgeID) }
    }

    func completeChallenge(_ challengeID: String, in seasonID: String) {
        update(seasonID) { $0.completedChallengeIDs.insert(challengeID) }
    }

    func unlockReward(_ rewardID: String, in seasonID: String) {
        update(seasonID) { $0.unlockedRewardIDs.insert(rewardID) }
    }

    func redeemReward(_ rewardID: String, in seasonID: String) {
        update(seasonID) { $0.redeemedRewardIDs.insert(rewardID) }
    }

    func setRaffle(_ raffle: SeasonRaffleProgress, in seasonID: String) {
        update(seasonID) { $0.raffle = raffle }
    }

    func resetProgress(in seasonID: String) {
        guard storageIsReadable else { return }
        progressBySeasonID[seasonID] = SeasonProgress()
        _ = persist()
    }

    /// Public for deterministic migration tests. Production runs it once after
    /// a successfully persisted migration marker, leaving legacy values as a
    /// recoverable backup and allowing a user to reset new progress later.
    func migrateLegacyValuesIfNeeded() {
        guard defaults.integer(forKey: Self.migrationKey) < 1 else { return }
        guard migrateLegacyValues() else { return }
        defaults.set(1, forKey: Self.migrationKey)
    }

    @discardableResult
    func migrateLegacyValues() -> Bool {
        guard storageIsReadable else { return false }
        migrateLegacyValues(for: "bergschein-2026", suffix: "")
        migrateLegacyValues(for: "bergschein-2027", suffix: ".2027")
        return persist()
    }

    /// The 2027 progress present before season-aware tracking shipped was
    /// explicitly confirmed to come from pre-release tests. Preserve it under
    /// the test scope instead of allowing it to contaminate production.
    func migrateConfirmedPreReleaseTestProgressIfNeeded() {
        guard defaults.integer(forKey: Self.testProgressMigrationKey) < 1 else { return }
        let productionID = "bergschein-2027"
        let testID = Self.storageSeasonID(for: productionID, isTestMode: true)
        if let existing = progressBySeasonID[productionID], existing != SeasonProgress() {
            var testProgress = progress(for: testID)
            testProgress.merge(existing)
            progressBySeasonID[testID] = testProgress
            progressBySeasonID.removeValue(forKey: productionID)
        }
        guard persist() else { return }
        defaults.set(1, forKey: Self.testProgressMigrationKey)
    }

    private func migrateLegacyValues(for seasonID: String, suffix: String) {
        let legacyBadges = csvSet(defaults.string(forKey: "unlockedBadgeIdentifiers"))
        let badges = suffix.isEmpty ? legacyBadges : csvSet(defaults.string(forKey: "unlockedBadgeIdentifiers\(suffix)"))
        let challenges = csvSet(defaults.string(forKey: "completedChallengeIdentifiers\(suffix)"))
        let legacyUnlockedRewards: Set<String> = [
            defaults.bool(forKey: "tbDrinkRewardUnlocked") ? ChallengeReward.tbBasketballDrink.id : nil,
            defaults.bool(forKey: "zirkelRewardUnlocked") ? ChallengeReward.zirkelFreeEntry.id : nil,
            defaults.bool(forKey: "bibOfferRewardUnlocked") ? ChallengeReward.bibOfferCode.id : nil
        ].compactMap { $0 }.reduce(into: Set<String>()) { $0.insert($1) }
        let legacyRedeemedRewards: Set<String> = [
            defaults.bool(forKey: "tbDrinkRewardRedeemed") ? ChallengeReward.tbBasketballDrink.id : nil,
            defaults.bool(forKey: "zirkelRewardRedeemed") ? ChallengeReward.zirkelFreeEntry.id : nil,
            defaults.bool(forKey: "bibOfferRewardRedeemed") ? ChallengeReward.bibOfferCode.id : nil
        ].compactMap { $0 }.reduce(into: Set<String>()) { $0.insert($1) }

        var record = progress(for: seasonID)
        let original = record
        record.unlockedBadgeIDs.formUnion(badges)
        record.completedChallengeIDs.formUnion(challenges)
        if suffix.isEmpty {
            record.unlockedRewardIDs.formUnion(legacyUnlockedRewards)
            record.redeemedRewardIDs.formUnion(legacyRedeemedRewards)
            if defaults.bool(forKey: "hasJoinedRaffle") { record.raffle.hasJoined = true }
            if record.raffle.consentTimestamp.isEmpty { record.raffle.consentTimestamp = defaults.string(forKey: "raffleConsentTimestamp") ?? "" }
            if record.raffle.contactEmail.isEmpty { record.raffle.contactEmail = defaults.string(forKey: "raffleContactEmail") ?? "" }
            if record.raffle.contactName.isEmpty { record.raffle.contactName = defaults.string(forKey: "raffleContactName") ?? "" }
        }
        if record != original || progressBySeasonID[seasonID] == nil {
            progressBySeasonID[seasonID] = record
        }
    }

    private func update(_ seasonID: String, _ mutate: (inout SeasonProgress) -> Void) {
        guard storageIsReadable else { return }
        var record = progress(for: seasonID)
        mutate(&record)
        progressBySeasonID[seasonID] = record
        _ = persist()
    }

    @discardableResult
    private func persist() -> Bool {
        guard let data = try? JSONEncoder().encode(progressBySeasonID) else { return false }
        defaults.set(data, forKey: Self.storageKey)
        return defaults.data(forKey: Self.storageKey) == data
    }

    private static func load(from defaults: UserDefaults) -> StoredProgress {
        guard let data = defaults.data(forKey: storageKey) else { return .missing }
        guard let progress = try? JSONDecoder().decode([String: SeasonProgress].self, from: data) else { return .invalid }
        return .valid(progress)
    }

    private func csvSet(_ value: String?) -> Set<String> {
        Set((value ?? "").split(separator: ",").map(String.init))
    }

    private enum StoredProgress {
        case missing
        case valid([String: SeasonProgress])
        case invalid
    }
}

private extension SeasonProgress {
    mutating func merge(_ other: SeasonProgress) {
        unlockedBadgeIDs.formUnion(other.unlockedBadgeIDs)
        completedChallengeIDs.formUnion(other.completedChallengeIDs)
        unlockedRewardIDs.formUnion(other.unlockedRewardIDs)
        redeemedRewardIDs.formUnion(other.redeemedRewardIDs)
        if !raffle.hasJoined, other.raffle.hasJoined {
            raffle = other.raffle
        }
    }
}
