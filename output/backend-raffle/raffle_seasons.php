<?php
declare(strict_types=1);

/**
 * Authoritative raffle rules. Keep these identifiers in sync with the iOS
 * SeasonCatalog and the track/community allowlists.
 *
 * All timestamps use the season's business timezone. A season is never
 * inferred from the server's current year or from a client-supplied date.
 *
 * @return array<string, array{registration_enabled:bool,registration_opens_at:?DateTimeImmutable,registration_closes_at:?DateTimeImmutable,draw_available_at:?DateTimeImmutable,terms_version:?string,event_starts_at:?DateTimeImmutable,event_ends_at:?DateTimeImmutable,is_test:bool}>
 */
function raffleSeasons(): array
{
    $timezone = new DateTimeZone('Europe/Berlin');
    $at = static fn (string $value): DateTimeImmutable => new DateTimeImmutable($value, $timezone);

    return [
        // Historical season: intentionally closed. Do not reopen by changing
        // only the app; amend the verified rules and terms here as well.
        'bergschein-2026' => [
            'registration_enabled' => false,
            'registration_opens_at' => $at('2026-04-02 00:00:00'),
            'registration_closes_at' => $at('2026-06-08 23:00:00'),
            'draw_available_at' => $at('2026-06-08 23:00:01'),
            'terms_version' => '2026-04-02',
            'event_starts_at' => $at('2026-05-21 17:00:00'),
            'event_ends_at' => $at('2026-06-01 23:00:00'),
            'is_test' => false,
        ],
        // Announcement only. The planned window is stored, but registration
        // remains disabled until final terms and draw rules are approved.
        'bergschein-2027' => [
            'registration_enabled' => false,
            'registration_opens_at' => $at('2027-04-29 00:00:00'),
            'registration_closes_at' => $at('2027-05-31 23:00:00'),
            'draw_available_at' => null,
            'terms_version' => null,
            'event_starts_at' => $at('2027-05-13 17:00:00'),
            'event_ends_at' => $at('2027-05-24 23:00:00'),
            'is_test' => false,
        ],
        // Test IDs are deliberately separate from production. They are closed
        // today but can be configured with their own verified window later.
        'test-bergschein-2026' => [
            'registration_enabled' => false,
            'registration_opens_at' => null,
            'registration_closes_at' => null,
            'draw_available_at' => null,
            'terms_version' => null,
            'event_starts_at' => $at('2026-05-21 17:00:00'),
            'event_ends_at' => $at('2026-06-01 23:00:00'),
            'is_test' => true,
        ],
        'test-bergschein-2027' => [
            'registration_enabled' => false,
            'registration_opens_at' => null,
            'registration_closes_at' => null,
            'draw_available_at' => null,
            'terms_version' => null,
            'event_starts_at' => $at('2027-05-13 17:00:00'),
            'event_ends_at' => $at('2027-05-24 23:00:00'),
            'is_test' => true,
        ],
    ];
}

/** @return array{registration_enabled:bool,registration_opens_at:?DateTimeImmutable,registration_closes_at:?DateTimeImmutable,draw_available_at:?DateTimeImmutable,terms_version:?string,event_starts_at:?DateTimeImmutable,event_ends_at:?DateTimeImmutable,is_test:bool}|null */
function raffleSeason(string $seasonId): ?array
{
    return raffleSeasons()[$seasonId] ?? null;
}

function raffleRegistrationIsOpen(array $season, DateTimeImmutable $now): bool
{
    return $season['registration_enabled']
        && $season['registration_opens_at'] !== null
        && $season['registration_closes_at'] !== null
        && $season['terms_version'] !== null
        && $now >= $season['registration_opens_at']
        && $now < $season['registration_closes_at'];
}

function raffleDrawIsAvailable(array $season, DateTimeImmutable $now): bool
{
    return $season['draw_available_at'] !== null
        && $season['event_ends_at'] !== null
        && $now >= $season['event_ends_at']
        && $now >= $season['draw_available_at'];
}

/**
 * analytics_events.event_time is stored as a naive UTC value by track.php.
 * Convert a season rule from Europe/Berlin before binding it to SQL.
 */
function raffleAnalyticsUtcTimestamp(DateTimeImmutable $moment): string
{
    return $moment->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d H:i:s');
}
