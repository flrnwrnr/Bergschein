<?php
declare(strict_types=1);

require_once __DIR__ . '/raffle_seasons.php';

header('Content-Type: application/json; charset=utf-8');
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(405, ['ok' => false, 'error' => 'method_not_allowed']);
}

$configPath = __DIR__ . '/config.php';
if (!is_file($configPath)) {
    jsonResponse(500, ['ok' => false, 'error' => 'missing_config']);
}
$config = require $configPath;
$auth = $config['dashboard_auth'] ?? [];
if (!isset($auth['user'], $auth['password'])
    || !hash_equals((string)$auth['user'], (string)($_SERVER['PHP_AUTH_USER'] ?? ''))
    || !hash_equals((string)$auth['password'], (string)($_SERVER['PHP_AUTH_PW'] ?? ''))) {
    header('WWW-Authenticate: Basic realm="Bergschein Draw"');
    jsonResponse(401, ['ok' => false, 'error' => 'unauthorized']);
}

try {
    $data = json_decode((string)file_get_contents('php://input'), true, 512, JSON_THROW_ON_ERROR);
} catch (JsonException $exception) {
    jsonResponse(400, ['ok' => false, 'error' => 'invalid_json']);
}
if (!is_array($data)) {
    jsonResponse(400, ['ok' => false, 'error' => 'invalid_payload']);
}

$seasonId = $data['season_id'] ?? 'bergschein-2026';
if (!is_string($seasonId) || ($season = raffleSeason($seasonId)) === null) {
    jsonResponse(422, ['ok' => false, 'error' => 'invalid_season_id']);
}
$now = new DateTimeImmutable('now', new DateTimeZone('Europe/Berlin'));
if (!raffleDrawIsAvailable($season, $now)) {
    jsonResponse(403, ['ok' => false, 'error' => 'draw_not_available']);
}

$count = max(1, min(10, (int)($data['count'] ?? 3)));
$minBadges = max(0, min(12, (int)($data['min_badges'] ?? 0)));

try {
    $pdo = new PDO(
        sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', (string)($config['db_host'] ?? 'localhost'), (int)($config['db_port'] ?? 3306), (string)($config['db_name'] ?? '')),
        (string)($config['db_user'] ?? ''), (string)($config['db_pass'] ?? ''),
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC, PDO::ATTR_EMULATE_PREPARES => false]
    );

    // The event table, not the client-provided consent counters, defines the
    // badge total. The same season ID is required on both sides of the join.
    $legacyNameSelect = $seasonId === 'bergschein-2026' ? 're.name, ' : '';
    $legacyNameGroup = $seasonId === 'bergschein-2026' ? ', re.name' : '';
    $eligibleSql = 'SELECT re.install_id, re.email, ' . $legacyNameSelect . 're.consent_at,
            MAX(ae.badge_count_after_event) AS badge_count
        FROM raffle_entries re
        INNER JOIN analytics_events ae
            ON ae.install_id = re.install_id
           AND ae.season_id = re.season_id
           AND ae.event_type = \'badge_claimed\'
           AND ae.event_time >= :event_starts_at
           AND ae.event_time < :event_ends_at
        WHERE re.season_id = :season_id
          AND re.contact_consent = 1
          AND re.age_confirmed = 1
          AND re.terms_version = :terms_version
        GROUP BY re.install_id, re.email, re.consent_at' . $legacyNameGroup . '
        HAVING MAX(ae.badge_count_after_event) >= :min_badges';
    $parameters = [
        ':event_starts_at' => raffleAnalyticsUtcTimestamp($season['event_starts_at']),
        ':event_ends_at' => raffleAnalyticsUtcTimestamp($season['event_ends_at']),
        ':season_id' => $seasonId,
        ':terms_version' => $season['terms_version'],
        ':min_badges' => $minBadges,
    ];
    $totalStatement = $pdo->prepare('SELECT COUNT(*) AS total FROM (' . $eligibleSql . ') eligible');
    $totalStatement->execute($parameters);
    $eligibleTotal = (int)($totalStatement->fetch()['total'] ?? 0);

    $winnerStatement = $pdo->prepare($eligibleSql . ' ORDER BY RAND() LIMIT ' . $count);
    $winnerStatement->execute($parameters);
    $winners = $winnerStatement->fetchAll();
} catch (Throwable $exception) {
    error_log('draw.php database error: ' . $exception->getMessage());
    jsonResponse(500, ['ok' => false, 'error' => 'server_error']);
}

jsonResponse(200, [
    'ok' => true, 'season_id' => $seasonId, 'is_test_season' => $season['is_test'],
    'eligible_total' => $eligibleTotal, 'draw_count' => count($winners),
    'min_badges' => $minBadges, 'drawn_at' => gmdate('c'), 'winners' => $winners,
]);

function jsonResponse(int $status, array $payload): void
{
    http_response_code($status);
    echo json_encode($payload);
    exit;
}
