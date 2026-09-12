<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(405, ['ok' => false, 'error' => 'method_not_allowed']);
}

$configPath = __DIR__ . '/config.php';
if (!file_exists($configPath)) {
    jsonResponse(500, ['ok' => false, 'error' => 'missing_config']);
}

$config = require $configPath;
$expectedToken = (string)($config['app_token'] ?? '');
$providedToken = (string)($_SERVER['HTTP_X_APP_TOKEN'] ?? '');

if ($expectedToken === '' || !hash_equals($expectedToken, $providedToken)) {
    jsonResponse(401, ['ok' => false, 'error' => 'unauthorized']);
}

$raw = file_get_contents('php://input');
if ($raw === false || $raw === '') {
    jsonResponse(400, ['ok' => false, 'error' => 'empty_body']);
}

try {
    $data = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);
} catch (JsonException $e) {
    jsonResponse(400, ['ok' => false, 'error' => 'invalid_json']);
}

if (!is_array($data)) {
    jsonResponse(400, ['ok' => false, 'error' => 'invalid_payload']);
}

// Missing season IDs belong to legacy apps (2026), never the current year.
$seasonId = $data['season_id'] ?? 'bergschein-2026';
if (!is_string($seasonId) || !in_array($seasonId, [
    'bergschein-2026', 'bergschein-2027',
    'test-bergschein-2026', 'test-bergschein-2027',
], true)) {
    jsonResponse(422, ['ok' => false, 'error' => 'invalid_season_id']);
}

$installId = (string)($data['install_id'] ?? '');
$eventType = (string)($data['event_type'] ?? '');
$eventTime = (string)($data['event_time'] ?? '');
$badgeCount = (int)($data['badge_count_after_event'] ?? -1);
$perfect = !empty($data['is_perfect_so_far']) ? 1 : 0;
$challengeCount = (int)($data['challenge_count_after_event'] ?? -1);

if (!preg_match('/^[a-f0-9-]{36}$/i', $installId)) {
    jsonResponse(422, ['ok' => false, 'error' => 'invalid_install_id']);
}

if (!in_array($eventType, ['badge_claimed', 'challenge_completed'], true)) {
    jsonResponse(422, ['ok' => false, 'error' => 'invalid_event_type']);
}

if ($badgeCount < 0 || $challengeCount < 0) {
    jsonResponse(422, ['ok' => false, 'error' => 'invalid_counter_values']);
}

try {
    $dt = new DateTimeImmutable($eventTime !== '' ? $eventTime : 'now');
} catch (Exception $e) {
    jsonResponse(422, ['ok' => false, 'error' => 'invalid_event_time']);
}

$dayKey = $dt->format('Y-m-d');
$eventTs = $dt->format('Y-m-d H:i:s');

$dbHost = (string)($config['db_host'] ?? 'localhost');
$dbPort = (int)($config['db_port'] ?? 3306);
$dbName = (string)($config['db_name'] ?? '');
$dbUser = (string)($config['db_user'] ?? '');
$dbPass = (string)($config['db_pass'] ?? '');

if ($dbName === '' || $dbUser === '') {
    jsonResponse(500, ['ok' => false, 'error' => 'invalid_db_config']);
}

try {
    $pdo = new PDO(
        sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', $dbHost, $dbPort, $dbName),
        $dbUser,
        $dbPass,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]
    );

    $sql = "INSERT INTO analytics_events
    (season_id, install_id, event_type, event_time, day_key, badge_count_after_event, is_perfect_so_far, challenge_count_after_event)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
      event_time = VALUES(event_time),
      badge_count_after_event = VALUES(badge_count_after_event),
      is_perfect_so_far = VALUES(is_perfect_so_far),
      challenge_count_after_event = VALUES(challenge_count_after_event)";

    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        $seasonId,
        $installId,
        $eventType,
        $eventTs,
        $dayKey,
        $badgeCount,
        $perfect,
        $challengeCount,
    ]);
} catch (Throwable $e) {
    jsonResponse(500, ['ok' => false, 'error' => 'db_write_failed']);
}

jsonResponse(200, ['ok' => true]);

function jsonResponse(int $statusCode, array $payload): void
{
    http_response_code($statusCode);
    echo json_encode($payload);
    exit;
}
