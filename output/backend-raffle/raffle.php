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
$expectedToken = (string)($config['app_token'] ?? '');
$providedToken = (string)($_SERVER['HTTP_X_APP_TOKEN'] ?? '');
if ($expectedToken === '' || !hash_equals($expectedToken, $providedToken)) {
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

// Legacy clients without a season are permanently assigned to 2026.
$seasonId = $data['season_id'] ?? 'bergschein-2026';
if (!is_string($seasonId) || ($season = raffleSeason($seasonId)) === null) {
    jsonResponse(422, ['ok' => false, 'error' => 'invalid_season_id']);
}
$now = new DateTimeImmutable('now', new DateTimeZone('Europe/Berlin'));
if (!raffleRegistrationIsOpen($season, $now)) {
    jsonResponse(403, ['ok' => false, 'error' => 'registration_closed']);
}

$installId = trim((string)($data['install_id'] ?? ''));
$email = trim((string)($data['email'] ?? ''));
$name = trim((string)($data['name'] ?? ''));
$termsVersion = trim((string)($data['terms_version'] ?? ''));
$contactConsent = filter_var($data['contact_consent'] ?? false, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
$ageConfirmed = filter_var($data['age_confirmed'] ?? false, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
$badgeCount = max(0, min(12, (int)($data['badge_count_at_consent'] ?? 0)));
$isLegacyRegistration = $seasonId === 'bergschein-2026';
$challengeCount = $isLegacyRegistration ? max(0, min(12, (int)($data['challenge_count_at_consent'] ?? 0))) : null;
$isPerfect = $isLegacyRegistration
    ? (filter_var($data['is_perfect_so_far'] ?? false, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE) === true ? 1 : 0)
    : null;

if (!preg_match('/^[a-f0-9-]{36}$/i', $installId)) {
    jsonResponse(422, ['ok' => false, 'error' => 'invalid_install_id']);
}
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    jsonResponse(422, ['ok' => false, 'error' => 'invalid_email']);
}
if (!hash_equals($season['terms_version'], $termsVersion)) {
    jsonResponse(422, ['ok' => false, 'error' => 'invalid_terms_version']);
}
if ($contactConsent !== true || $ageConfirmed !== true) {
    jsonResponse(422, ['ok' => false, 'error' => 'consent_required']);
}
// Ignore names from older clients during 2027 registration as well.
$name = $seasonId === 'bergschein-2026' && $name !== '' ? mb_substr($name, 0, 120) : null;

try {
    $pdo = new PDO(
        sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', (string)($config['db_host'] ?? 'localhost'), (int)($config['db_port'] ?? 3306), (string)($config['db_name'] ?? '')),
        (string)($config['db_user'] ?? ''),
        (string)($config['db_pass'] ?? ''),
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_EMULATE_PREPARES => false]
    );
    // The migration makes (season_id, install_id) unique, so resubmission is
    // idempotent within a season and cannot overwrite a different season.
    $legacyColumns = $isLegacyRegistration ? ', challenge_count_at_consent, is_perfect_so_far' : '';
    $legacyValues = $isLegacyRegistration ? ', :challenge_count, :is_perfect' : '';
    $legacyUpdates = $isLegacyRegistration
        ? ', challenge_count_at_consent = VALUES(challenge_count_at_consent), is_perfect_so_far = VALUES(is_perfect_so_far)'
        : '';
    $statement = $pdo->prepare('INSERT INTO raffle_entries
        (season_id, install_id, email, name, terms_version, contact_consent, age_confirmed, consent_at,
         badge_count_at_consent' . $legacyColumns . ')
        VALUES (:season_id, :install_id, :email, :name, :terms_version, 1, 1, NOW(),
         :badge_count' . $legacyValues . ')
        ON DUPLICATE KEY UPDATE
            email = VALUES(email), name = VALUES(name), terms_version = VALUES(terms_version),
            contact_consent = 1, age_confirmed = 1, consent_at = NOW(),
            badge_count_at_consent = VALUES(badge_count_at_consent)' . $legacyUpdates);
    $parameters = [
        ':season_id' => $seasonId, ':install_id' => $installId, ':email' => $email,
        ':name' => $name, ':terms_version' => $termsVersion, ':badge_count' => $badgeCount,
    ];
    if ($isLegacyRegistration) {
        $parameters[':challenge_count'] = $challengeCount;
        $parameters[':is_perfect'] = $isPerfect;
    }
    $statement->execute($parameters);
} catch (Throwable $exception) {
    error_log('raffle.php database error: ' . $exception->getMessage());
    jsonResponse(500, ['ok' => false, 'error' => 'server_error']);
}

jsonResponse(200, ['ok' => true, 'season_id' => $seasonId]);

function jsonResponse(int $status, array $payload): void
{
    http_response_code($status);
    echo json_encode($payload);
    exit;
}
