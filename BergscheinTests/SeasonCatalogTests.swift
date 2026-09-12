import Combine
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

        var seasonCalendar = Calendar(identifier: .gregorian)
        seasonCalendar.timeZone = TimeZone(identifier: "America/New_York")!

        XCTAssertTrue(challenge.spansMidnight)
        XCTAssertEqual(challenge.endDate(in: seasonCalendar)!.timeIntervalSince(challenge.startDate(in: seasonCalendar)!), 2 * 60 * 60)
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
        let progress2027 = store.progress(for: "test-bergschein-2027")

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

    func testProgressActionsUpdateOnlyTheirSeasonRecord() {
        let suiteName = "SeasonCatalogTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SeasonProgressStore(defaults: defaults)
        let seasonID = "test-season"

        store.unlockBadge("badge-1", in: seasonID)
        store.completeChallenge("challenge-1", in: seasonID)
        store.unlockReward("reward-1", in: seasonID)
        store.redeemReward("reward-1", in: seasonID)
        store.setRaffle(
            SeasonRaffleProgress(
                hasJoined: true,
                consentTimestamp: "2026-05-21T10:00:00Z",
                contactEmail: "test@example.com",
                contactName: "Test User"
            ),
            in: seasonID
        )

        let progress = store.progress(for: seasonID)
        XCTAssertEqual(progress.unlockedBadgeIDs, ["badge-1"])
        XCTAssertEqual(progress.completedChallengeIDs, ["challenge-1"])
        XCTAssertEqual(progress.unlockedRewardIDs, ["reward-1"])
        XCTAssertEqual(progress.redeemedRewardIDs, ["reward-1"])
        XCTAssertTrue(progress.raffle.hasJoined)
        XCTAssertEqual(progress.raffle.consentTimestamp, "2026-05-21T10:00:00Z")
        XCTAssertEqual(progress.raffle.contactEmail, "test@example.com")
        XCTAssertEqual(progress.raffle.contactName, "Test User")
        XCTAssertEqual(store.progress(for: "other-season"), SeasonProgress())
    }

    func testProgressActionsPersistAcrossReopeningStore() {
        let suiteName = "SeasonCatalogTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let seasonID = "persistent-season"
        let expected = SeasonProgress(
            unlockedBadgeIDs: ["badge-1"],
            completedChallengeIDs: ["challenge-1"],
            unlockedRewardIDs: ["reward-1"],
            redeemedRewardIDs: ["reward-1"],
            raffle: SeasonRaffleProgress(
                hasJoined: true,
                consentTimestamp: "2026-05-21T10:00:00Z",
                contactEmail: "test@example.com",
                contactName: "Test User"
            )
        )

        let store = SeasonProgressStore(defaults: defaults)
        store.unlockBadge("badge-1", in: seasonID)
        store.completeChallenge("challenge-1", in: seasonID)
        store.unlockReward("reward-1", in: seasonID)
        store.redeemReward("reward-1", in: seasonID)
        store.setRaffle(expected.raffle, in: seasonID)

        let reopenedStore = SeasonProgressStore(defaults: defaults)
        XCTAssertEqual(reopenedStore.progress(for: seasonID), expected)
    }

    func testLegacyAnalyticsPayloadWithoutSeasonIsQuarantined() throws {
        let legacyPayload = Data(#"{"install_id":"install","event_type":"badge_claimed","event_time":"2026-05-21T17:00:00Z","badge_count_after_event":1,"is_perfect_so_far":true,"challenge_count_after_event":0}"#.utf8)

        let payload = try JSONDecoder().decode(AnalyticsService.EventPayload.self, from: legacyPayload)

        XCTAssertEqual(payload.seasonID, AnalyticsService.EventPayload.quarantinedLegacySeasonID)
        let encodedPayload = try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as! [String: Any]
        XCTAssertEqual(encodedPayload["season_id"] as? String, AnalyticsService.EventPayload.quarantinedLegacySeasonID)
        XCTAssertEqual(encodedPayload["install_id"] as? String, "install")
    }

    func testSeasonAwarePayloadEncodesSeasonAndQueuedWrapperPreservesOrigin() throws {
        let legacyInnerPayload = Data(#"{"install_id":"install","event_type":"badge_claimed","event_time":"2027-05-13T17:00:00Z","badge_count_after_event":1,"is_perfect_so_far":true,"challenge_count_after_event":0}"#.utf8)
        let payload = try JSONDecoder().decode(AnalyticsService.EventPayload.self, from: legacyInnerPayload)
        let queued = AnalyticsService.QueuedEvent(payload: payload, seasonID: "test-bergschein-2027")

        XCTAssertEqual(payload.seasonID, AnalyticsService.EventPayload.quarantinedLegacySeasonID)
        XCTAssertEqual(queued.payloadForUpload.seasonID, "test-bergschein-2027")
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(queued.payloadForUpload)) as! [String: Any]
        XCTAssertEqual(encoded["season_id"] as? String, "test-bergschein-2027")
    }

    func testOldV2Production2027WrapperMigratesToConfirmedTestOrigin() throws {
        let legacyInnerPayload = Data(#"{"install_id":"install","event_type":"badge_claimed","event_time":"2027-05-13T17:00:00Z","badge_count_after_event":1,"is_perfect_so_far":true,"challenge_count_after_event":0}"#.utf8)
        let payload = try JSONDecoder().decode(AnalyticsService.EventPayload.self, from: legacyInnerPayload)
        let old2027 = AnalyticsService.QueuedEvent(payload: payload, seasonID: "bergschein-2027")
        let historical2026 = AnalyticsService.QueuedEvent(payload: payload, seasonID: "bergschein-2026")

        let migrated = AnalyticsService.migratingConfirmedPreReleaseOrigins([old2027, historical2026])

        XCTAssertEqual(migrated.map(\.seasonID), ["test-bergschein-2027", "bergschein-2026"])
        XCTAssertEqual(migrated[0].payloadForUpload.seasonID, "test-bergschein-2027")
        XCTAssertEqual(migrated.map(\.id), [old2027.id, historical2026.id])
    }

    func testReleasedV1QueueMigratesExplicitlyTo2026() throws {
        let legacyData = Data(#"{"install_id":"install","event_type":"badge_claimed","event_time":"2026-05-21T17:00:00Z","badge_count_after_event":1,"is_perfect_so_far":true,"challenge_count_after_event":0}"#.utf8)
        let payload = try JSONDecoder().decode(AnalyticsService.EventPayload.self, from: legacyData)

        let migrated = AnalyticsService.migratingLegacyV1Events([payload])

        XCTAssertEqual(payload.seasonID, AnalyticsService.EventPayload.quarantinedLegacySeasonID)
        XCTAssertEqual(migrated.first?.seasonID, "bergschein-2026")
        XCTAssertEqual(migrated.first?.payloadForUpload.seasonID, "bergschein-2026")
    }

    func testMalformedV2QueueWithoutWrapperOriginIsQuarantined() throws {
        let data = Data(#"{"payload":{"install_id":"install","event_type":"badge_claimed","event_time":"2027-05-13T17:00:00Z","badge_count_after_event":1,"is_perfect_so_far":true,"challenge_count_after_event":0}}"#.utf8)

        let queued = try JSONDecoder().decode(AnalyticsService.QueuedEvent.self, from: data)

        XCTAssertEqual(queued.seasonID, AnalyticsService.EventPayload.quarantinedLegacySeasonID)
    }

    func testFlushMergePreservesEventsQueuedWhileRequestWasSuspended() {
        let payload = AnalyticsService.EventPayload(
            installID: "install",
            eventType: AnalyticsEventType.badgeClaimed.rawValue,
            eventTime: "2027-05-13T17:00:00Z",
            badgeCountAfterEvent: 1,
            isPerfectSoFar: true,
            challengeCountAfterEvent: 0,
            seasonID: "test-bergschein-2027"
        )
        let sent = AnalyticsService.QueuedEvent(payload: payload, seasonID: payload.seasonID)
        let failed = AnalyticsService.QueuedEvent(payload: payload, seasonID: payload.seasonID)
        let queuedDuringFlush = AnalyticsService.QueuedEvent(payload: payload, seasonID: payload.seasonID)

        let merged = AnalyticsService.mergingFlushResult(
            remaining: [failed],
            current: [sent, failed, queuedDuringFlush],
            originalIDs: [sent.id, failed.id]
        )

        XCTAssertEqual(merged.map(\.id), [failed.id, queuedDuringFlush.id])
    }

    func testCommunityStatsURLCarriesRequestedSeasonWithoutDroppingExistingQuery() throws {
        let url = try XCTUnwrap(AnalyticsService.communityStatsURL(
            endpoint: "https://example.com/community.php?format=json&season_id=old",
            seasonID: "test-bergschein-2027"
        ))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.queryItems?.filter { $0.name == "season_id" }.map(\.value), ["test-bergschein-2027"])
        XCTAssertEqual(components.queryItems?.first { $0.name == "format" }?.value, "json")
    }

    func testConfirmedPreRelease2027ProgressMovesToTestScope() throws {
        let suiteName = "SeasonCatalogTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let existing = ["bergschein-2027": SeasonProgress(unlockedBadgeIDs: ["2027-05-13"])]
        defaults.set(try JSONEncoder().encode(existing), forKey: SeasonProgressStore.storageKey)
        defaults.set(1, forKey: SeasonProgressStore.migrationKey)

        let store = SeasonProgressStore(defaults: defaults)

        XCTAssertEqual(store.progress(for: "bergschein-2027"), SeasonProgress())
        XCTAssertEqual(store.progress(for: "test-bergschein-2027").unlockedBadgeIDs, ["2027-05-13"])
        XCTAssertEqual(defaults.integer(forKey: SeasonProgressStore.testProgressMigrationKey), 1)
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

@MainActor
final class ContentViewStoreTests: XCTestCase {
    private var suiteNames: [String] = []

    override func tearDown() async throws {
        let suiteNames = self.suiteNames
        self.suiteNames.removeAll()
        for suiteName in suiteNames {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        try await super.tearDown()
    }

    func testClaimEligibilityHonorsOpeningLocationAndExistingProgress() {
        let beforeOpening = makeDate(year: 2026, month: 5, day: 21, hour: 16)
        let store = makeStore(date: beforeOpening)

        XCTAssertFalse(store.canClaimToday(isInAllowedRegion: true))

        store.currentDate = makeDate(year: 2026, month: 5, day: 21, hour: 17)
        XCTAssertFalse(store.canClaimToday(isInAllowedRegion: false))
        XCTAssertTrue(store.canClaimToday(isInAllowedRegion: true))

        store.seasonProgressStore.unlockBadge("05-21", in: "bergschein-2026")
        XCTAssertFalse(store.canClaimToday(isInAllowedRegion: true))
    }

    func testChildProgressChangesPublishDerivedState() {
        let store = makeStore(date: makeDate(year: 2026, month: 5, day: 21, hour: 17))
        let expectation = expectation(description: "store publishes progress changes")
        var cancellable: AnyCancellable?
        cancellable = store.objectWillChange.sink {
            expectation.fulfill()
            cancellable?.cancel()
        }

        store.seasonProgressStore.unlockBadge("05-21", in: "bergschein-2026")

        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(store.isCurrentBadgeUnlocked)
        XCTAssertEqual(store.activeSeasonProgress.unlockedBadgeIDs, ["05-21"])
    }

    func testSeasonScopeFiltersUnknownProgressIdentifiers() {
        let store = makeStore(date: makeDate(year: 2027, month: 5, day: 13, hour: 12))
        store.seasonProgressStore.unlockBadge("2027-05-13", in: "bergschein-2027")
        store.seasonProgressStore.unlockBadge("unknown-badge", in: "bergschein-2027")
        store.seasonProgressStore.completeChallenge("unknown-challenge", in: "bergschein-2027")

        XCTAssertEqual(store.unlockedBadges, ["2027-05-13"])
        XCTAssertTrue(store.completedChallenges.isEmpty)
        XCTAssertFalse(store.isChallengeRewardRedeemed(makeReward(id: "unknown-reward")))
        XCTAssertNil(store.seasonProgressStore.progress(for: "unconfigured-season").unlockedBadgeIDs.first)
    }

    func testTestModeSeparatesProgressAndAnalyticsSeasonFromProduction() async {
        let recorder = AnalyticsEventGate()
        let date = makeDate(year: 2026, month: 5, day: 21, hour: 17)
        let store = ContentViewStore(
            seasonProgressStore: makeProgressStore(),
            now: { date },
            analyticsTracker: { event in await recorder.track(event) }
        )
        store.setTestModeActive(true)

        let claim = Task {
            await store.claimBadge(isInAllowedRegion: true, analyticsInstallID: "install")
        }
        await recorder.waitUntilEntered()

        XCTAssertEqual(store.communitySeasonID, "test-bergschein-2026")
        XCTAssertEqual(store.activeSeasonProgress.unlockedBadgeIDs, ["05-21"])
        XCTAssertEqual(store.seasonProgressStore.progress(for: "bergschein-2026"), SeasonProgress())

        store.setTestModeActive(false)
        XCTAssertEqual(store.communitySeasonID, "bergschein-2026")
        XCTAssertTrue(store.activeSeasonProgress.unlockedBadgeIDs.isEmpty)

        await recorder.release()
        _ = await claim.value
        let events = await recorder.events
        XCTAssertEqual(events.first?.seasonID, "test-bergschein-2026")
    }

    func testMissedBadgeAndStreakReflectProgressBeforeCurrentBadge() {
        let date = makeDate(year: 2026, month: 5, day: 23, hour: 12)
        let store = makeStore(date: date)
        store.seasonProgressStore.unlockBadge("05-21", in: "bergschein-2026")

        XCTAssertEqual(store.currentBadge?.id, "05-23")
        XCTAssertEqual(store.blockingMissedBadge?.id, "05-22")
        XCTAssertEqual(store.currentStreak, 0)

        store.seasonProgressStore.unlockBadge("05-22", in: "bergschein-2026")
        XCTAssertNil(store.blockingMissedBadge)
        XCTAssertEqual(store.currentStreak, 0)
        store.seasonProgressStore.unlockBadge("05-23", in: "bergschein-2026")
        XCTAssertEqual(store.currentStreak, 3)
    }

    func testChallengePreviewPlaceholderAndCompletionAreSeasonScoped() {
        let previewStore = makeStore(date: makeDate(year: 2027, month: 5, day: 13, hour: 12))
        XCTAssertEqual(previewStore.activeBadgeSeason.id, "bergschein-2027")
        XCTAssertNil(previewStore.activeChallenge)
        XCTAssertTrue(previewStore.challengeDefinitions.dropFirst().allSatisfy(\.isPlaceholder))

        let activeStore = makeStore(date: makeDate(year: 2026, month: 5, day: 22, hour: 21))
        XCTAssertEqual(activeStore.activeChallenge?.id, "2026-05-22")
        XCTAssertTrue(activeStore.isWithinChallengeWindow(DailyChallenge.all[1]))
        activeStore.seasonProgressStore.completeChallenge("2026-05-22", in: "bergschein-2026")
        XCTAssertEqual(activeStore.completedChallengesCount, 1)
        XCTAssertFalse(activeStore.canCheckInForActiveChallenge { _ in true })
    }

    func testChallengeRewardRedemptionUsesExclusiveEndAndCannotBeClaimedTwice() {
        let reward = ChallengeReward.zirkelFreeEntry
        let store = makeStore(date: makeDate(year: 2026, month: 7, day: 31, hour: 23))
        store.seasonProgressStore.unlockReward(reward.id, in: "bergschein-2026")

        XCTAssertTrue(store.canRedeemChallengeReward(reward))
        XCTAssertNotNil(store.redeemChallengeReward(reward))
        XCTAssertFalse(store.canRedeemChallengeReward(reward))
        XCTAssertNil(store.redeemChallengeReward(reward))

        let afterEnd = makeStore(date: makeDate(year: 2026, month: 8, day: 1, hour: 0))
        afterEnd.seasonProgressStore.unlockReward(reward.id, in: "bergschein-2026")
        XCTAssertFalse(afterEnd.canRedeemChallengeReward(reward))
    }

    func testSyncCurrentDateUsesInjectedClock() {
        var clock = makeDate(year: 2026, month: 5, day: 21, hour: 17)
        let store = ContentViewStore(seasonProgressStore: makeProgressStore(), now: { clock })

        XCTAssertEqual(store.currentDate, clock)
        clock = makeDate(year: 2026, month: 5, day: 22, hour: 17)
        store.syncCurrentDate()
        XCTAssertEqual(store.currentDate, clock)
        XCTAssertEqual(store.currentBadge?.id, "05-22")
    }

    func testBadgeClaimEmitsSnapshotAndDuplicateClaimIsRejected() async {
        let recorder = AnalyticsEventGate()
        let date = makeDate(year: 2026, month: 5, day: 21, hour: 17)
        let store = ContentViewStore(
            seasonProgressStore: makeProgressStore(),
            now: { date },
            analyticsTracker: { event in await recorder.track(event) }
        )

        let firstClaim = Task {
            await store.claimBadge(isInAllowedRegion: true, analyticsInstallID: "install")
        }
        await recorder.waitUntilEntered()
        XCTAssertTrue(store.isCurrentBadgeUnlocked)

        let duplicate = await store.claimBadge(isInAllowedRegion: true, analyticsInstallID: "install")
        XCTAssertNil(duplicate)
        store.currentDate = makeDate(year: 2027, month: 5, day: 13, hour: 12)
        XCTAssertEqual(store.activeBadgeSeason.id, "bergschein-2027")

        await recorder.release()
        let result = await firstClaim.value
        let events = await recorder.events

        XCTAssertEqual(result?.badge.id, "05-21")
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.eventType, .badgeClaimed)
        XCTAssertEqual(events.first?.badgeCountAfterEvent, 1)
        XCTAssertTrue(events.first?.isPerfectSoFar == true)
        XCTAssertEqual(events.first?.seasonID, "bergschein-2026")
    }

    func testChallengeClaimUnlocksRewardAndEmitsSnapshot() async {
        let recorder = AnalyticsEventGate()
        let date = makeDate(year: 2026, month: 5, day: 22, hour: 21)
        let store = ContentViewStore(
            seasonProgressStore: makeProgressStore(),
            now: { date },
            analyticsTracker: { event in await recorder.track(event) }
        )
        var accepted = false

        let firstClaim = Task {
            await store.claimActiveChallenge(
                isWithinRadius: { _ in true },
                analyticsInstallID: "install",
                onClaimAccepted: { accepted = true }
            )
        }
        await recorder.waitUntilEntered()
        XCTAssertTrue(accepted)
        XCTAssertTrue(store.completedChallenges.contains("2026-05-22"))
        XCTAssertTrue(store.activeSeasonProgress.unlockedRewardIDs.contains(ChallengeReward.zirkelFreeEntry.id))

        store.currentDate = makeDate(year: 2027, month: 5, day: 13, hour: 12)
        XCTAssertEqual(store.activeBadgeSeason.id, "bergschein-2027")
        await recorder.release()
        let result = await firstClaim.value
        let events = await recorder.events

        XCTAssertEqual(result?.unlockedReward?.id, ChallengeReward.zirkelFreeEntry.id)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.eventType, .challengeCompleted)
        XCTAssertEqual(events.first?.challengeCountAfterEvent, 1)
    }

    func testCommunityViewModelFailedReloadClearsPreviouslyLoadedStats() async {
        let model = CommunityViewModel { seasonID in
            guard seasonID == "seed" else {
                throw CommunityViewModelTestError.unavailable
            }
            return CommunityStats(
                generatedAt: "",
                basis: "",
                totalCollectors: 1,
                averageCheckins: 1,
                maxCheckins: 12,
                distribution: []
            )
        }

        await model.load(seasonID: "seed")
        XCTAssertNotNil(model.stats)

        await model.load(seasonID: "failed-reload")
        XCTAssertNil(model.stats)
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.errorMessage, String(localized: "Bitte versuche es in ein paar Sekunden erneut."))
    }

    func testCommunityViewModelDoesNotApplyOlderSuccessfulResponseAfterNewerFailure() async {
        let gate = CommunityRequestGate()
        let model = CommunityViewModel { seasonID in
            if seasonID == "older-season" {
                await gate.startAndWaitForRelease()
                return CommunityStats(
                    generatedAt: "",
                    basis: "",
                    totalCollectors: 1,
                    averageCheckins: 1,
                    maxCheckins: 12,
                    distribution: []
                )
            }
            throw CommunityViewModelTestError.unavailable
        }

        let olderRequest = Task { @MainActor in
            await model.load(seasonID: "older-season")
        }
        await gate.waitUntilStarted()

        await model.load(seasonID: "newer-season")
        await gate.release()
        await olderRequest.value

        XCTAssertNil(model.stats)
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.errorMessage, String(localized: "Bitte versuche es in ein paar Sekunden erneut."))
    }

    func testCommunityViewModelFinishesCancelledRequestWhenFetcherIgnoresCancellation() async {
        let gate = CommunityRequestGate()
        let model = CommunityViewModel { _ in
            await gate.startAndWaitForRelease()
            return nil
        }

        let request = Task { @MainActor in
            await model.load(seasonID: "test-bergschein-2027")
        }
        await gate.waitUntilStarted()
        request.cancel()
        await gate.release()
        await request.value

        XCTAssertNil(model.stats)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    private func makeStore(date: Date) -> ContentViewStore {
        ContentViewStore(seasonProgressStore: makeProgressStore(), now: { date })
    }

    private func makeProgressStore() -> SeasonProgressStore {
        let suiteName = "ContentViewStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Could not create isolated UserDefaults suite")
        }
        suiteNames.append(suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        return SeasonProgressStore(defaults: defaults)
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        BergscheinDateHelper.date(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: 0,
            calendar: BergscheinDateHelper.eventCalendar
        ) ?? Date(timeIntervalSince1970: 0)
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

private actor AnalyticsEventGate {
    private(set) var events: [ContentViewStore.AnalyticsTrackingEvent] = []
    private var entered = false
    private var entryContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func track(_ event: ContentViewStore.AnalyticsTrackingEvent) async {
        entered = true
        entryContinuation?.resume()
        entryContinuation = nil
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
        events.append(event)
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { continuation in
            entryContinuation = continuation
        }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

private enum CommunityViewModelTestError: Error {
    case unavailable
}

private actor CommunityRequestGate {
    private var didStart = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func startAndWaitForRelease() async {
        didStart = true
        startContinuation?.resume()
        startContinuation = nil
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func waitUntilStarted() async {
        guard !didStart else { return }
        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
