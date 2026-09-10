import XCTest
@testable import Bergschein

@MainActor
final class SeasonCatalogTests: XCTestCase {
    func testSeasonBoundariesAreExplicitAndEndIsExclusive() {
        let season = SeasonCatalog.all[0]

        XCTAssertEqual(season.phase(at: season.openingDate.addingTimeInterval(-1)), .preview)
        XCTAssertEqual(season.phase(at: season.openingDate), .active)
        XCTAssertEqual(season.phase(at: season.endDate.addingTimeInterval(-1)), .active)
        XCTAssertEqual(season.phase(at: season.endDate), .followUp)
        XCTAssertEqual(season.phase(at: season.archiveStartDate), .archived)
    }

    func testCatalogRejectsAnEmptyActiveWindow() {
        let season = SeasonCatalog.all[0]
        let invalidSeason = SeasonDefinition(
            id: "invalid-empty-window",
            configurationVersion: SeasonCatalog.configurationVersion,
            title: "Invalid",
            timeZoneIdentifier: "Europe/Berlin",
            previewStartsAt: season.previewStartsAt,
            openingAt: season.openingAt,
            endsAt: season.openingAt,
            archiveStartsAt: season.archiveStartsAt,
            badges: [],
            challenges: [],
            rewards: [],
            raffle: nil
        )

        XCTAssertTrue(SeasonCatalog.validate([invalidSeason]).contains { $0.contains("Ungültige Saisonzeiten") })
    }

    func testCatalogSelectsOnlyKnownSeasonsAndNeverMakesAnUnknownYearPlayable() {
        let season2026 = SeasonCatalog.all[0]
        let season2027 = SeasonCatalog.all[1]

        XCTAssertEqual(SeasonCatalog.displayedSeason(at: season2026.archiveStartDate).id, season2027.id)
        XCTAssertEqual(SeasonCatalog.displayedSeason(at: season2027.openingDate).id, season2027.id)
        XCTAssertNil(SeasonCatalog.playableSeason(at: date(year: 2028, month: 5, day: 20, hour: 12)))
        XCTAssertTrue(SeasonCatalog.validate().isEmpty)
        let rewardIDs = SeasonCatalog.all.flatMap(\.rewards).map(\.id)
        XCTAssertEqual(Set(rewardIDs).count, rewardIDs.count)
    }

    func testMidnightChallengeWindowUsesTheSeasonTimeZone() {
        let challenge = DailyChallenge(
            id: "midnight",
            icon: "🌙",
            title: "Nachtchallenge",
            text: "",
            locationName: "",
            month: 5,
            day: 21,
            year: 2027,
            startHour: 23,
            startMinute: 0,
            endHour: 1,
            endMinute: 0,
            centerCoordinate: nil,
            radius: nil,
            requiresLocationCheckIn: false
        )

        XCTAssertTrue(challenge.spansMidnight)
        XCTAssertEqual(challenge.endDate!.timeIntervalSince(challenge.startDate!), 2 * 60 * 60)
    }

    func testLegacyMigrationIsAdditiveAndRunsOnlyOnce() {
        let suiteName = "SeasonCatalogTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("05-21,05-22", forKey: "unlockedBadgeIdentifiers")
        defaults.set("2026-05-21", forKey: "completedChallengeIdentifiers")
        defaults.set(true, forKey: "zirkelRewardUnlocked")
        defaults.set(true, forKey: "zirkelRewardRedeemed")
        defaults.set(true, forKey: "hasJoinedRaffle")
        defaults.set("2026-06-02T10:00:00Z", forKey: "raffleConsentTimestamp")
        defaults.set("test@example.com", forKey: "raffleContactEmail")
        defaults.set("Test User", forKey: "raffleContactName")
        defaults.set("05-13", forKey: "unlockedBadgeIdentifiers.2027")
        defaults.set("2027-05-13", forKey: "completedChallengeIdentifiers.2027")

        let store = SeasonProgressStore(defaults: defaults)
        let progress2026 = store.progress(for: "bergschein-2026")
        let progress2027 = store.progress(for: "bergschein-2027")

        XCTAssertEqual(progress2026.unlockedBadgeIDs, ["05-21", "05-22"])
        XCTAssertEqual(progress2026.completedChallengeIDs, ["2026-05-21"])
        XCTAssertEqual(progress2026.unlockedRewardIDs, [ChallengeReward.zirkelFreeEntry.id])
        XCTAssertEqual(progress2026.redeemedRewardIDs, [ChallengeReward.zirkelFreeEntry.id])
        XCTAssertTrue(progress2026.raffle.hasJoined)
        XCTAssertEqual(progress2026.raffle.contactEmail, "test@example.com")
        XCTAssertEqual(progress2027.unlockedBadgeIDs, ["05-13"])
        XCTAssertEqual(progress2027.completedChallengeIDs, ["2027-05-13"])

        store.resetProgress(in: "bergschein-2026")
        defaults.set("05-23", forKey: "unlockedBadgeIdentifiers")
        let reopenedStore = SeasonProgressStore(defaults: defaults)
        XCTAssertEqual(reopenedStore.progress(for: "bergschein-2026"), SeasonProgress())
        XCTAssertEqual(defaults.integer(forKey: SeasonProgressStore.migrationKey), 1)
    }

    func testUnreadableStoredProgressIsNeverReplacedOrMarkedMigrated() {
        let suiteName = "SeasonCatalogTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let corruptedData = Data([0x00, 0x01, 0x02])
        defaults.set(corruptedData, forKey: SeasonProgressStore.storageKey)
        defaults.set("05-21", forKey: "unlockedBadgeIdentifiers")

        let store = SeasonProgressStore(defaults: defaults)
        store.unlockBadge("05-22", in: "bergschein-2026")

        XCTAssertEqual(defaults.data(forKey: SeasonProgressStore.storageKey), corruptedData)
        XCTAssertEqual(defaults.integer(forKey: SeasonProgressStore.migrationKey), 0)
        XCTAssertEqual(store.progress(for: "bergschein-2026"), SeasonProgress())
    }

    func testLegacyAnalyticsPayloadKeepsTheNetworkContractAndDefaultsTo2026() throws {
        let legacyPayload = Data(#"{"install_id":"install","event_type":"badge_claimed","event_time":"2026-05-21T17:00:00Z","badge_count_after_event":1,"is_perfect_so_far":true,"challenge_count_after_event":0}"#.utf8)

        let payload = try JSONDecoder().decode(AnalyticsService.EventPayload.self, from: legacyPayload)

        XCTAssertEqual(payload.seasonID, "bergschein-2026")
        let encodedPayload = try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as! [String: Any]
        XCTAssertNil(encodedPayload["season_id"])
        XCTAssertEqual(encodedPayload["install_id"] as? String, "install")
    }

    func testRewardFollowUpWindowUsesConfiguredExclusiveEnd() {
        let season = SeasonCatalog.all[0]
        let reward = ChallengeReward.zirkelFreeEntry
        let starts = reward.redemptionStartsAt!.date(in: season.calendar)
        let ends = reward.redemptionEndsAt!.date(in: season.calendar)

        XCTAssertLessThan(starts, ends)
        XCTAssertEqual(ends, date(year: 2026, month: 8, day: 1, hour: 0))
    }

    func testUnlockedRewardGroupsSortNewestSeasonFirstAndOmitEmptySeasons() {
        let reward2026 = makeReward(id: "reward-2026")
        let reward2028 = makeReward(id: "reward-2028")
        let seasons = [
            makeSeason(id: "season-2026", year: 2026, rewards: [reward2026]),
            makeSeason(id: "season-2028", year: 2028, rewards: [reward2028]),
            makeSeason(id: "season-2027", year: 2027, rewards: [makeReward(id: "reward-2027")])
        ]
        let progressBySeasonID = [
            "season-2026": SeasonProgress(unlockedRewardIDs: [reward2026.id]),
            "season-2028": SeasonProgress(unlockedRewardIDs: [reward2028.id])
        ]

        let groups = ChallengeRewardSeasonGroup.unlocked(in: seasons) {
            progressBySeasonID[$0] ?? SeasonProgress()
        }

        XCTAssertEqual(groups.map(\.id), ["season-2028", "season-2026"])
        XCTAssertEqual(groups.map(\.title), ["2028", "2026"])
    }

    func testUnlockedRewardGroupsPreserveRewardCatalogOrder() {
        let firstReward = makeReward(id: "first")
        let lockedReward = makeReward(id: "locked")
        let lastReward = makeReward(id: "last")
        let season = makeSeason(
            id: "season-2030",
            year: 2030,
            rewards: [firstReward, lockedReward, lastReward]
        )
        let progress = SeasonProgress(unlockedRewardIDs: [lastReward.id, firstReward.id])

        let groups = ChallengeRewardSeasonGroup.unlocked(in: [season]) { _ in progress }

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].rewards.map(\.id), [firstReward.id, lastReward.id])
    }

    private func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        BergscheinDateHelper.date(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: 0,
            calendar: BergscheinDateHelper.eventCalendar
        )!
    }

    private func makeSeason(id: String, year: Int, rewards: [ChallengeReward]) -> SeasonDefinition {
        SeasonDefinition(
            id: id,
            configurationVersion: SeasonCatalog.configurationVersion,
            title: String(year),
            timeZoneIdentifier: "Europe/Berlin",
            previewStartsAt: SeasonMoment(year: year, month: 1, day: 1, hour: 0, minute: 0),
            openingAt: SeasonMoment(year: year, month: 1, day: 2, hour: 0, minute: 0),
            endsAt: SeasonMoment(year: year, month: 1, day: 3, hour: 0, minute: 0),
            archiveStartsAt: SeasonMoment(year: year, month: 1, day: 4, hour: 0, minute: 0),
            badges: [],
            challenges: [],
            rewards: rewards,
            raffle: nil
        )
    }

    private func makeReward(id: String) -> ChallengeReward {
        ChallengeReward(
            id: id,
            icon: "",
            imageName: nil,
            title: id,
            subtitle: "",
            details: "",
            infoURL: nil,
            redemptionHint: "",
            redemptionStartsAt: nil,
            redemptionEndsAt: nil,
            redemptionURL: nil
        )
    }
}
