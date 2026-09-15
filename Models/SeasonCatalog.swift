import Foundation

/// A local, versioned description of one Bergschein season. Adding a future
/// season is a data change in this catalog; views and persistence use `id`.
struct SeasonDefinition: Identifiable, Hashable {
    let id: String
    let configurationVersion: Int
    let title: String
    let timeZoneIdentifier: String
    let previewStartsAt: SeasonMoment
    let openingAt: SeasonMoment
    let endsAt: SeasonMoment
    let archiveStartsAt: SeasonMoment
    let badges: [BadgeDefinition]
    let challenges: [DailyChallenge]
    let rewards: [ChallengeReward]
    let raffle: RaffleConfiguration?

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? BergscheinDateHelper.eventCalendar.timeZone
        return calendar
    }

    var previewStartDate: Date { previewStartsAt.date(in: calendar) }
    var openingDate: Date { openingAt.date(in: calendar) }
    var endDate: Date { endsAt.date(in: calendar) }
    var archiveStartDate: Date { archiveStartsAt.date(in: calendar) }

    func phase(at date: Date) -> SeasonPhase {
        if date < previewStartDate { return .preparation }
        if date < openingDate { return .preview }
        if date < endDate { return .active }
        if date < archiveStartDate { return .followUp }
        return .archived
    }

    func reward(withID id: String) -> ChallengeReward? {
        rewards.first { $0.id == id }
    }

    static func == (lhs: SeasonDefinition, rhs: SeasonDefinition) -> Bool {
        lhs.id == rhs.id && lhs.configurationVersion == rhs.configurationVersion
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(configurationVersion)
    }
}

struct SeasonMoment: Codable, Hashable {
    let year: Int
    let month: Int
    let day: Int
    let hour: Int
    let minute: Int

    func date(in calendar: Calendar) -> Date {
        BergscheinDateHelper.date(
            year: year, month: month, day: day, hour: hour, minute: minute,
            calendar: calendar
        )!
    }
}

enum SeasonPhase: String, Codable, CaseIterable {
    case preparation
    case preview
    case active
    case followUp
    case archived

    var permitsClaims: Bool { self == .active }
}

enum RafflePhase: String, Codable, Hashable, CaseIterable {
    case hidden
    case announced
    case registrationOpen
    case registrationClosed
}

enum RafflePrizePublication: Hashable {
    case comingSoon
    case published([RafflePrizeItem])

    var prizes: [RafflePrizeItem] {
        guard case let .published(prizes) = self else { return [] }
        return prizes
    }
}

/// Registers the in-app text that belongs to a published terms version.
/// Adding a version here and the associated text in the raffle view happens
/// together, so a future season cannot fall back to a previous season's text.
enum RaffleTermsCatalog {
    static let legacy2026Version = "2026-04-02"
    static let terms2027Version = "2026-09-15"

    static func hasText(for version: String, seasonID: String) -> Bool {
        switch (seasonID, version) {
        case ("bergschein-2026", legacy2026Version),
             ("bergschein-2027", terms2027Version):
            true
        default:
            false
        }
    }
}

struct RaffleConfiguration: Hashable {
    let phase: RafflePhase
    let prizePublication: RafflePrizePublication
    let registrationStartsAt: SeasonMoment?
    let termsVersion: String
    let participationDeadline: SeasonMoment?

    var prizes: [RafflePrizeItem] { prizePublication.prizes }
    var isVisible: Bool { phase != .hidden }
    func hasTermsText(for seasonID: String) -> Bool {
        RaffleTermsCatalog.hasText(for: termsVersion, seasonID: seasonID)
    }

    init(
        phase: RafflePhase,
        prizePublication: RafflePrizePublication,
        registrationStartsAt: SeasonMoment? = nil,
        termsVersion: String = "",
        participationDeadline: SeasonMoment? = nil
    ) {
        self.phase = phase
        self.prizePublication = prizePublication
        self.registrationStartsAt = registrationStartsAt
        self.termsVersion = termsVersion
        self.participationDeadline = participationDeadline
    }

    func registrationStartDate(in calendar: Calendar) -> Date? {
        registrationStartsAt?.date(in: calendar)
    }

    func participationDeadlineDate(in calendar: Calendar) -> Date? {
        participationDeadline?.date(in: calendar)
    }

    func isRegistrationOpen(at date: Date, in calendar: Calendar) -> Bool {
        guard phase == .registrationOpen,
              let registrationStartDate = registrationStartDate(in: calendar),
              let participationDeadlineDate = participationDeadlineDate(in: calendar) else {
            return false
        }
        return registrationStartDate <= date && date < participationDeadlineDate
    }
}

struct ChallengeRewardSeasonGroup: Identifiable {
    let id: String
    let title: String
    let rewards: [ChallengeReward]

    static func unlocked(
        in seasons: [SeasonDefinition],
        progressForSeason: (String) -> SeasonProgress
    ) -> [ChallengeRewardSeasonGroup] {
        seasons
            .sorted {
                if $0.openingDate == $1.openingDate {
                    return $0.id > $1.id
                }
                return $0.openingDate > $1.openingDate
            }
            .compactMap { season in
                let unlockedRewardIDs = progressForSeason(season.id).unlockedRewardIDs
                let rewards = season.rewards.filter { unlockedRewardIDs.contains($0.id) }
                guard !rewards.isEmpty else { return nil }
                return ChallengeRewardSeasonGroup(id: season.id, title: season.title, rewards: rewards)
            }
    }
}

enum SeasonCatalog {
    static let configurationVersion = 1
    static let all: [SeasonDefinition] = [season2026, season2027Preview]

    static func season(id: String) -> SeasonDefinition? {
        all.first { $0.id == id }
    }

    /// The season shown by default. A known preview is visible only after the
    /// preceding season has reached its archive phase; it never makes claims
    /// available before its opening time.
    static func displayedSeason(at date: Date) -> SeasonDefinition {
        if let liveOrFollowUp = all.last(where: {
            let phase = $0.phase(at: date)
            return phase == .active || phase == .followUp
        }) {
            return liveOrFollowUp
        }
        if let preview = all.first(where: { $0.phase(at: date) == .preview }) {
            return preview
        }
        if let archived = all.last(where: { $0.phase(at: date) == .archived }) {
            return archived
        }
        return all[0]
    }

    static func playableSeason(at date: Date) -> SeasonDefinition? {
        all.first { $0.phase(at: date).permitsClaims }
    }

    static func nextKnownSeason(after date: Date) -> SeasonDefinition? {
        all.first { $0.openingDate > date }
    }

    static func validate(_ seasons: [SeasonDefinition] = all) -> [String] {
        var errors: [String] = []
        var identifiers = Set<String>()
        var rewardIdentifiers = Set<String>()
        for season in seasons {
            if !identifiers.insert(season.id).inserted { errors.append("Doppelte Saison-ID: \(season.id)") }
            if season.configurationVersion != configurationVersion { errors.append("Unbekannte Konfigurationsversion für \(season.id)") }
            if !(season.previewStartDate <= season.openingDate && season.openingDate < season.endDate && season.endDate < season.archiveStartDate) {
                errors.append("Ungültige Saisonzeiten für \(season.id)")
            }
            let badgeIDs = season.badges.map(\.id)
            if Set(badgeIDs).count != badgeIDs.count { errors.append("Doppelte Badge-ID in \(season.id)") }
            let challengeIDs = season.challenges.map(\.id)
            if Set(challengeIDs).count != challengeIDs.count { errors.append("Doppelte Challenge-ID in \(season.id)") }
            let rewardIDs = season.rewards.map(\.id)
            if Set(rewardIDs).count != rewardIDs.count { errors.append("Doppelte Belohnungs-ID in \(season.id)") }
            for rewardID in rewardIDs where !rewardIdentifiers.insert(rewardID).inserted {
                errors.append("Saisonübergreifend doppelte Belohnungs-ID: \(rewardID)")
            }
            for challenge in season.challenges {
                if let rewardID = challenge.rewardID, !rewardIDs.contains(rewardID) {
                    errors.append("Unbekannte Belohnung \(rewardID) in \(challenge.id)")
                }
            }
            if let raffle = season.raffle {
                if case let .published(prizes) = raffle.prizePublication, prizes.isEmpty {
                    errors.append("Veröffentlichte Preisliste ist leer in \(season.id)")
                }

                let registrationStartDate = raffle.registrationStartDate(in: season.calendar)
                let participationDeadlineDate = raffle.participationDeadlineDate(in: season.calendar)
                if let registrationStartDate, let participationDeadlineDate,
                   registrationStartDate >= participationDeadlineDate {
                    errors.append("Ungültiger Verlosungszeitraum für \(season.id)")
                }

                if raffle.phase == .registrationOpen {
                    let hasPublishedPrizes: Bool
                    if case let .published(prizes) = raffle.prizePublication {
                        hasPublishedPrizes = !prizes.isEmpty
                    } else {
                        hasPublishedPrizes = false
                    }
                    if registrationStartDate == nil || participationDeadlineDate == nil ||
                        raffle.termsVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        !raffle.hasTermsText(for: season.id) ||
                        !hasPublishedPrizes {
                        errors.append("Unvollständige offene Verlosung für \(season.id)")
                    }
                }
            }
        }
        for (index, season) in seasons.enumerated() {
            for other in seasons.dropFirst(index + 1) {
                if season.openingDate < other.endDate && other.openingDate < season.endDate {
                    errors.append("Überlappende aktive Saisons: \(season.id), \(other.id)")
                }
            }
        }
        return errors
    }

    private static let season2026 = SeasonDefinition(
        id: "bergschein-2026",
        configurationVersion: configurationVersion,
        title: "2026",
        timeZoneIdentifier: "Europe/Berlin",
        previewStartsAt: SeasonMoment(year: 2026, month: 4, day: 2, hour: 0, minute: 0),
        openingAt: SeasonMoment(year: 2026, month: 5, day: 21, hour: 17, minute: 0),
        // This is deliberately an explicit business deadline, not badge count.
        endsAt: SeasonMoment(year: 2026, month: 6, day: 1, hour: 23, minute: 0),
        archiveStartsAt: SeasonMoment(year: 2026, month: 6, day: 9, hour: 0, minute: 0),
        badges: BadgeDefinition.all,
        challenges: DailyChallenge.all,
        rewards: [.zirkelFreeEntry, .tbBasketballDrink, .bibOfferCode],
        raffle: RaffleConfiguration(
            phase: .registrationClosed,
            prizePublication: .published(RafflePrizeItem.legacy2026),
            registrationStartsAt: SeasonMoment(year: 2026, month: 4, day: 2, hour: 0, minute: 0),
            termsVersion: RaffleTermsCatalog.legacy2026Version,
            participationDeadline: SeasonMoment(year: 2026, month: 6, day: 8, hour: 23, minute: 0)
        )
    )

    private static let season2027Preview = SeasonDefinition(
        id: "bergschein-2027",
        configurationVersion: configurationVersion,
        title: "2027",
        timeZoneIdentifier: "Europe/Berlin",
        previewStartsAt: SeasonMoment(year: 2026, month: 6, day: 9, hour: 0, minute: 0),
        openingAt: SeasonMoment(year: 2027, month: 5, day: 13, hour: 17, minute: 0),
        endsAt: SeasonMoment(year: 2027, month: 5, day: 24, hour: 23, minute: 0),
        archiveStartsAt: SeasonMoment(year: 2027, month: 6, day: 1, hour: 0, minute: 0),
        badges: BadgeDefinition.preview2027,
        challenges: DailyChallenge.placeholders2027,
        rewards: [],
        raffle: RaffleConfiguration(
            phase: .announced,
            prizePublication: .comingSoon,
            registrationStartsAt: SeasonMoment(year: 2027, month: 4, day: 29, hour: 0, minute: 0),
            termsVersion: RaffleTermsCatalog.terms2027Version,
            participationDeadline: SeasonMoment(year: 2027, month: 5, day: 31, hour: 23, minute: 0)
        )
    )
}

/// Compatibility spelling for the season selector while the feature moves
/// away from a year enum. There are intentionally no generated future years.
typealias BadgeSeason = SeasonDefinition
