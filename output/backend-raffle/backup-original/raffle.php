<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['ok' => false, 'error' => 'method_not_allowed']);
    exit;
}

$config = require __DIR__ . '/config.php';

$token = $_SERVER['HTTP_X_APP_TOKEN'] ?? '';
if (!hash_equals((string)$config['app_token'], (string)$token)) {
    http_response_code(401);
    echo json_encode(['ok' => false, 'error' => 'unauthorized']);
    exit;
}

$raw = file_get_contents('php://input');
$data = json_decode($raw, true);

if (!is_array($data)) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid_json']);
    exit;
}

$installId = trim((string)($data['install_id'] ?? ''));
$email = trim((string)($data['email'] ?? ''));
$name = trim((string)($data['name'] ?? ''));
$termsVersion = trim((string)($data['terms_version'] ?? ''));
$contactConsent = filter_var($data['contact_consent'] ?? false, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
$ageConfirmed = filter_var($data['age_confirmed'] ?? false, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
$badgeCount = (int)($data['badge_count_at_consent'] ?? 0);
$challengeCount = (int)($data['challenge_count_at_consent'] ?? 0);
$isPerfect = filter_var($data['is_perfect_so_far'] ?? false, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);

if (!preg_match('/^[a-f0-9-]{36}$/i', $installId)) {
    http_response_code(422);
    echo json_encode(['ok' => false, 'error' => 'invalid_install_id']);
    exit;
}
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(422);
    echo json_encode(['ok' => false, 'error' => 'invalid_email']);
    exit;
}
if ($termsVersion === '') {
    http_response_code(422);
    echo json_encode(['ok' => false, 'error' => 'missing_terms_version']);
    exit;
}
if ($contactConsent !== true || $ageConfirmed !== true) {
    http_response_code(422);
    echo json_encode(['ok' => false, 'error' => 'consent_required']);
    exit;
}

$badgeCount = max(0, min(12, $badgeCount));
$challengeCount = max(0, min(12, $challengeCount));
$isPerfect = $isPerfect ? 1 : 0;
$name = $name !== '' ? mb_substr($name, 0, 120) : null;

try {
    $pdo = new PDO(
        "mysql:host={$config['db_host']};dbname={$config['db_name']};charset=utf8mb4",
        (string)$config['db_user'],
        (string)$config['db_pass'],
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]
    );

    // Idempotent: one row per install_id, update on repeated submit.
    $sql = "
        INSERT INTO raffle_entries (
            install_id,
            email,
            name,
            terms_version,
            contact_consent,
            age_confirmed,
            consent_at,
            badge_count_at_consent,
            challenge_count_at_consent,
            is_perfect_so_far
        ) VALUES (
            :install_id,
            :email,
            :name,
            :terms_version,
            1,
            1,
            NOW(),
            :badge_count,
            :challenge_count,
            :is_perfect
        )
        ON DUPLICATE KEY UPDATE
            email = VALUES(email),
            name = VALUES(name),
            terms_version = VALUES(terms_version),
            contact_consent = VALUES(contact_consent),
            age_confirmed = VALUES(age_confirmed),
            consent_at = NOW(),
            badge_count_at_consent = VALUES(badge_count_at_consent),
            challenge_count_at_consent = VALUES(challenge_count_at_consent),
            is_perfect_so_far = VALUES(is_perfect_so_far)
    ";

    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':install_id' => $installId,
        ':email' => $email,
        ':name' => $name,
        ':terms_version' => $termsVersion,
        ':badge_count' => $badgeCount,
        ':challenge_count' => $challengeCount,
        ':is_perfect' => $isPerfect,
    ]);

    echo json_encode(['ok' => true]);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'error' => 'server_error']);
}