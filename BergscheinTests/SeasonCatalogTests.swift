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
}
