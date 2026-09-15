<?php
declare(strict_types=1);

require_once __DIR__ . '/../raffle_seasons.php';

function expect(bool $condition, string $message): void {
    if (!$condition) { throw new RuntimeException($message); }
}

$seasons = raffleSeasons();
expect(array_keys($seasons) === ['bergschein-2026', 'bergschein-2027', 'test-bergschein-2026', 'test-bergschein-2027'], 'allowlist differs from app contract');
expect(raffleSeason('unknown') === null, 'unknown season must fail');
expect($seasons['test-bergschein-2026']['is_test'], 'test season must remain marked as test');
expect(!$seasons['bergschein-2026']['is_test'], 'production season must not be a test season');
expect(!raffleRegistrationIsOpen($seasons['bergschein-2026'], new DateTimeImmutable('2026-09-14 12:00:00', new DateTimeZone('Europe/Berlin'))), '2026 must be closed');
expect(!$seasons['bergschein-2027']['registration_enabled'], '2027 must remain closed until final rules are configured');
expect($seasons['bergschein-2027']['registration_opens_at']?->format('Y-m-d H:i:s') === '2027-04-29 00:00:00', '2027 planned start must be two weeks before the event');
expect($seasons['bergschein-2027']['registration_closes_at']?->format('Y-m-d H:i:s') === '2027-05-31 23:00:00', '2027 planned deadline must be one week after the event');
expect($seasons['bergschein-2027']['terms_version'] === null, '2027 must not have terms before final approval');
expect($seasons['bergschein-2027']['draw_available_at'] === null, '2027 draw must stay unavailable');
expect($seasons['bergschein-2027']['event_starts_at']->format('Y-m-d H:i:s') === '2027-05-13 17:00:00', '2027 event start must remain unchanged');
expect($seasons['bergschein-2027']['event_ends_at']->format('Y-m-d H:i:s') === '2027-05-24 23:00:00', '2027 event end must remain unchanged');
expect(!raffleRegistrationIsOpen($seasons['bergschein-2027'], new DateTimeImmutable('2026-09-15 09:00:00', new DateTimeZone('Europe/Berlin'))), '2027 must remain closed at this timestamp');
expect(!raffleRegistrationIsOpen($seasons['bergschein-2027'], new DateTimeImmutable('2027-04-29 00:00:00', new DateTimeZone('Europe/Berlin'))), '2027 must not open at the planned start without approved terms and enablement');
expect(!raffleRegistrationIsOpen($seasons['bergschein-2027'], new DateTimeImmutable('2027-05-14 12:00:00', new DateTimeZone('Europe/Berlin'))), '2027 must remain closed during the event');
expect(!raffleRegistrationIsOpen($seasons['test-bergschein-2027'], new DateTimeImmutable('2027-05-14 12:00:00', new DateTimeZone('Europe/Berlin'))), 'test registration must be closed');
expect(raffleDrawIsAvailable($seasons['bergschein-2026'], new DateTimeImmutable('2026-06-08 23:00:01', new DateTimeZone('Europe/Berlin'))), '2026 draw availability boundary is wrong');
expect(!raffleDrawIsAvailable($seasons['bergschein-2026'], new DateTimeImmutable('2026-06-01 23:00:00', new DateTimeZone('Europe/Berlin'))), 'draw must not be available before the season has ended');
expect(!raffleDrawIsAvailable($seasons['bergschein-2027'], new DateTimeImmutable('2027-06-02 12:00:00', new DateTimeZone('Europe/Berlin'))), '2027 draw must stay unavailable');

// Boundary coverage uses an isolated rule; none of the configured seasons is
// opened for a test, which prevents tests from weakening production defaults.
$openRule = $seasons['test-bergschein-2027'];
$openRule['registration_enabled'] = true;
$openRule['registration_opens_at'] = new DateTimeImmutable('2030-01-01 10:00:00', new DateTimeZone('Europe/Berlin'));
$openRule['registration_closes_at'] = new DateTimeImmutable('2030-01-01 12:00:00', new DateTimeZone('Europe/Berlin'));
$openRule['terms_version'] = 'test-terms-v1';
expect(!raffleRegistrationIsOpen($openRule, new DateTimeImmutable('2030-01-01 09:59:59', new DateTimeZone('Europe/Berlin'))), 'registration must not open early');
expect(raffleRegistrationIsOpen($openRule, new DateTimeImmutable('2030-01-01 10:00:00', new DateTimeZone('Europe/Berlin'))), 'registration opening boundary is wrong');
expect(raffleRegistrationIsOpen($openRule, new DateTimeImmutable('2030-01-01 11:59:59', new DateTimeZone('Europe/Berlin'))), 'registration must remain open before deadline');
expect(!raffleRegistrationIsOpen($openRule, new DateTimeImmutable('2030-01-01 12:00:00', new DateTimeZone('Europe/Berlin'))), 'registration deadline must be exclusive');
expect(raffleAnalyticsUtcTimestamp($seasons['bergschein-2027']['event_starts_at']) === '2027-05-13 15:00:00', '2027 opening must convert 17:00 Berlin to 15:00 UTC');
expect(raffleAnalyticsUtcTimestamp($seasons['bergschein-2026']['event_ends_at']) === '2026-06-01 21:00:00', '2026 daylight-saving event end must convert to UTC');
echo "raffle season tests passed\n";
