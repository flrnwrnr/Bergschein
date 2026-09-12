<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: public, max-age=300');

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    jsonResponse(405, ['ok' => false, 'error' => 'method_not_allowed']);
}

$configPath = __DIR__ . '/config.php';
if (!is_file($configPath)) {
    jsonResponse(500, ['ok' => false, 'error' => 'missing_config']);
}

$config = require $configPath;
$expectedToken = (string)($config['app_token'] ?? '');
$providedToken = (string)($_SERVER['HTTP_X_APP_TOKEN'] ?? '');

if ($expectedToken === '' || !hash_equals($expectedToken, $providedToken)) {
    jsonResponse(401, ['ok' => false, 'error' => 'unauthorized']);
}

// Missing season IDs belong to legacy apps (2026), never the current year.
$seasonId = $_GET['season_id'] ?? 'bergschein-2026';
if (!is_string($seasonId) || !in_array($seasonId, [
    'bergschein-2026', 'bergschein-2027',
    'test-bergschein-2026', 'test-bergschein-2027',
], true)) {
    jsonResponse(422, ['ok' => false, 'error' => 'invalid_season_id']);
}

$maxCheckins = (int)($_GET['max_checkins'] ?? 12);
$maxCheckins = max(1, min(100, $maxCheckins));

try {
    $pdo = new PDO(
        sprintf(
            'mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4',
            (string)($config['db_host'] ?? 'localhost'),
            (int)($config['db_port'] ?? 3306),
            (string)($config['db_name'] ?? '')
        ),
        (string)($config['db_user'] ?? ''),
        (string)($config['db_pass'] ?? ''),
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]
    );

    $distribution = fetchCheckinDistribution($pdo, $maxCheckins, $seasonId);
    $totalCollectors = array_sum(array_column($distribution, 'users'));
    $averageCheckins = calculateAverageCheckins($distribution, $totalCollectors);

    echo json_encode([
        'ok' => true,
        'generated_at' => gmdate('c'),
        'basis' => 'installations_with_at_least_one_badge_claim',
        'total_collectors' => $totalCollectors,
        'average_checkins' => $averageCheckins,
        'max_checkins' => $maxCheckins,
        'distribution' => addPercentages($distribution, $totalCollectors),
    ]);
} catch (Throwable $e) {
    jsonResponse(500, ['ok' => false, 'error' => 'server_error']);
}

function fetchCheckinDistribution(PDO $pdo, int $maxCheckins, string $seasonId): array
{
    $sql = <<<SQL
SELECT max_badges AS checkins, COUNT(*) AS users
FROM (
  SELECT install_id, LEAST(MAX(badge_count_after_event), :max_checkins) AS max_badges
  FROM analytics_events
  WHERE season_id = :season_id
    AND event_type = 'badge_claimed'
    AND badge_count_after_event > 0
  GROUP BY install_id
) t
GROUP BY max_badges
ORDER BY max_badges ASC
SQL;

    $stmt = $pdo->prepare($sql);
    $stmt->bindValue(':season_id', $seasonId, PDO::PARAM_STR);
    $stmt->bindValue(':max_checkins', $maxCheckins, PDO::PARAM_INT);
    $stmt->execute();

    $byCheckins = [];
    foreach ($stmt->fetchAll() as $row) {
        $byCheckins[(int)$row['checkins']] = (int)$row['users'];
    }

    $distribution = [];
    for ($i = 1; $i <= $maxCheckins; $i++) {
        $distribution[] = [
            'checkins' => $i,
            'users' => $byCheckins[$i] ?? 0,
        ];
    }

    return $distribution;
}

function addPercentages(array $distribution, int $totalCollectors): array
{
    return array_map(
        static fn(array $row): array => [
            'checkins' => $row['checkins'],
            'users' => $row['users'],
            'percentage' => $totalCollectors > 0
                ? round($row['users'] / $totalCollectors * 100, 1)
                : 0.0,
        ],
        $distribution
    );
}

function calculateAverageCheckins(array $distribution, int $totalCollectors): float
{
    if ($totalCollectors === 0) {
        return 0.0;
    }

    $weightedSum = 0;
    foreach ($distribution as $row) {
        $weightedSum += $row['checkins'] * $row['users'];
    }

    return round($weightedSum / $totalCollectors, 1);
}

function jsonResponse(int $statusCode, array $payload): void
{
    http_response_code($statusCode);
    echo json_encode($payload);
    exit;
}
