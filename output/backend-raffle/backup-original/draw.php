<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['ok' => false, 'error' => 'method_not_allowed']);
    exit;
}

$config = require __DIR__ . '/config.php';

/**
 * Admin/Auth für Draw:
 * Empfohlen: Basic Auth über dashboard_auth (nicht app_token).
 */
$auth = $config['dashboard_auth'] ?? [];
$user = (string)($_SERVER['PHP_AUTH_USER'] ?? '');
$pass = (string)($_SERVER['PHP_AUTH_PW'] ?? '');

if (
    !isset($auth['user'], $auth['password']) ||
    !hash_equals((string)$auth['user'], $user) ||
    !hash_equals((string)$auth['password'], $pass)
) {
    header('WWW-Authenticate: Basic realm="Bergschein Draw"');
    http_response_code(401);
    echo json_encode(['ok' => false, 'error' => 'unauthorized']);
    exit;
}

$raw = file_get_contents('php://input');
$data = json_decode((string)$raw, true);
if (!is_array($data)) {
    $data = [];
}

$count = (int)($data['count'] ?? 3);
$count = max(1, min(10, $count));

$minBadges = (int)($data['min_badges'] ?? 0);
$minBadges = max(0, min(12, $minBadges));

try {
    $pdo = new PDO(
        sprintf(
            'mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4',
            (string)$config['db_host'],
            (int)($config['db_port'] ?? 3306),
            (string)$config['db_name']
        ),
        (string)$config['db_user'],
        (string)$config['db_pass'],
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]
    );

    $eligibleStmt = $pdo->prepare("
        SELECT COUNT(*) AS cnt
        FROM raffle_entries
        WHERE contact_consent = 1
          AND age_confirmed = 1
          AND badge_count_at_consent >= :min_badges
    ");
    $eligibleStmt->bindValue(':min_badges', $minBadges, PDO::PARAM_INT);
    $eligibleStmt->execute();
    $eligibleTotal = (int)($eligibleStmt->fetch()['cnt'] ?? 0);

    if ($eligibleTotal === 0) {
        echo json_encode([
            'ok' => true,
            'eligible_total' => 0,
            'draw_count' => 0,
            'min_badges' => $minBadges,
            'winners' => [],
        ]);
        exit;
    }

    $sql = sprintf("
        SELECT
          install_id,
          email,
          name,
          badge_count_at_consent,
          challenge_count_at_consent,
          is_perfect_so_far,
          consent_at
        FROM raffle_entries
        WHERE contact_consent = 1
          AND age_confirmed = 1
          AND badge_count_at_consent >= :min_badges
        ORDER BY RAND()
        LIMIT %d
    ", $count);

    $stmt = $pdo->prepare($sql);
    $stmt->bindValue(':min_badges', $minBadges, PDO::PARAM_INT);
    $stmt->execute();
    $winners = $stmt->fetchAll();

    echo json_encode([
        'ok' => true,
        'eligible_total' => $eligibleTotal,
        'draw_count' => count($winners),
        'min_badges' => $minBadges,
        'drawn_at' => gmdate('c'),
        'winners' => $winners,
    ]);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'error' => 'server_error']);
}
