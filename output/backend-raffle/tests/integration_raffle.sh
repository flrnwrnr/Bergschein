#!/usr/bin/env bash
# Runs only against a disposable, localhost-bound MariaDB container.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_dir="$(cd "$script_dir/.." && pwd)"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/bergschein-raffle-it.XXXXXX")"
container_name="bergschein-raffle-it-$$"
server_pid=''

cleanup() {
    if [[ -n "$server_pid" ]]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    docker rm -f "$container_name" >/dev/null 2>&1 || true
    rm -rf "$tmp_dir"
}
trap cleanup EXIT

require_command() { command -v "$1" >/dev/null || { printf 'Missing required command: %s\n' "$1" >&2; exit 69; }; }
require_command php
require_command docker
require_command curl
php_bin="${PHP_BINARY:-$(command -v php)}"
if [[ -x /opt/homebrew/bin/php ]] && /opt/homebrew/bin/php -r 'exit(extension_loaded("pdo_mysql") ? 0 : 1);'; then
    php_bin=/opt/homebrew/bin/php
fi
"$php_bin" -r 'exit(extension_loaded("pdo_mysql") ? 0 : 1);' || { printf 'PHP extension pdo_mysql is required.\n' >&2; exit 69; }

cp "$package_dir/raffle.php" "$tmp_dir/raffle.php"
cp "$package_dir/draw.php" "$tmp_dir/draw.php"
"$php_bin" "$script_dir/prepare_integration_fixture.php" "$package_dir" "$tmp_dir"

docker run --rm --detach --name "$container_name" \
    --publish 127.0.0.1::3306 \
    --env MARIADB_ROOT_PASSWORD=integration-root-password \
    --env MARIADB_DATABASE=raffle_integration \
    --env MARIADB_USER=integration_user \
    --env MARIADB_PASSWORD=integration-db-password \
    mariadb:10.6 >/dev/null

for _ in {1..30}; do
    if docker exec "$container_name" mariadb -u integration_user --password=integration-db-password raffle_integration -e 'SELECT 1' >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
docker exec "$container_name" mariadb -u integration_user --password=integration-db-password raffle_integration -e 'SELECT 1' >/dev/null
db_port="$(docker port "$container_name" 3306/tcp | sed -n 's/.*:\([0-9][0-9]*\)$/\1/p')"
[[ -n "$db_port" ]] || { printf 'Could not determine MariaDB port.\n' >&2; exit 70; }
docker exec -i "$container_name" mariadb -u integration_user --password=integration-db-password raffle_integration < "$script_dir/integration_schema.sql"

cat > "$tmp_dir/config.php" <<PHP
<?php
return [
    'app_token' => 'integration-app-token',
    'db_host' => '127.0.0.1', 'db_port' => $db_port,
    'db_name' => 'raffle_integration', 'db_user' => 'integration_user', 'db_pass' => 'integration-db-password',
    'dashboard_auth' => ['user' => 'integration-admin', 'password' => 'integration-dashboard-password'],
];
PHP

http_port="$("$php_bin" -r '$socket=stream_socket_server("tcp://127.0.0.1:0", $error, $message); if (!$socket) exit(1); echo explode(":", stream_socket_get_name($socket, false))[1]; fclose($socket);')"
"$php_bin" -S "127.0.0.1:$http_port" -t "$tmp_dir" >"$tmp_dir/php-server.log" 2>&1 &
server_pid=$!
sleep 1

request() {
    local name="$1" path="$2" payload="$3" status_expected="$4" error_expected="$5" auth_header="${6:-}"
    local body="$tmp_dir/$name.json" status
    local args=(--silent --show-error --output "$body" --write-out '%{http_code}' --request POST --header 'Content-Type: application/json' --data "$payload")
    [[ -n "$auth_header" ]] && args+=(--header "$auth_header")
    status="$(curl "${args[@]}" "http://127.0.0.1:$http_port/$path")"
    [[ "$status" == "$status_expected" ]] || { printf '%s: expected HTTP %s, got %s\n' "$name" "$status_expected" "$status" >&2; exit 1; }
    "$php_bin" -r '$data=json_decode(file_get_contents($argv[1]), true); exit(($data["error"] ?? null) === $argv[2] ? 0 : 1);' "$body" "$error_expected" \
        || { printf '%s: unexpected response body\n' "$name" >&2; exit 1; }
    printf 'PASS %s\n' "$name"
}

token='X-App-Token: integration-app-token'
request missing_season raffle.php '{}' 403 registration_closed "$token"
request invalid_season raffle.php '{"season_id":"not-a-season"}' 422 invalid_season_id "$token"
request closed_2027 raffle.php '{"season_id":"bergschein-2027"}' 403 registration_closed "$token"
request closed_test_2027 raffle.php '{"season_id":"test-bergschein-2027"}' 403 registration_closed "$token"
request invalid_terms raffle.php '{"season_id":"local-open-production","install_id":"11111111-1111-1111-1111-111111111111","email":"fixture@example.test","terms_version":"wrong","contact_consent":true,"age_confirmed":true}' 422 invalid_terms_version "$token"

registration_payload() {
    local season="$1"
    printf '{"season_id":"%s","install_id":"11111111-1111-1111-1111-111111111111","email":"fixture@example.test","terms_version":"integration-v1","contact_consent":true,"age_confirmed":true,"challenge_count_at_consent":12,"is_perfect_so_far":true}' "$season"
}
for season in local-open-production local-open-test; do
    body="$tmp_dir/register-$season.json"
    status="$(curl --silent --show-error --output "$body" --write-out '%{http_code}' --request POST --header 'Content-Type: application/json' --header "$token" --data "$(registration_payload "$season")" "http://127.0.0.1:$http_port/raffle.php")"
    [[ "$status" == 200 ]] || { printf 'registration for %s failed\n' "$season" >&2; exit 1; }
done
entry_count="$(docker exec "$container_name" mariadb -N -u integration_user --password=integration-db-password raffle_integration -e "SELECT COUNT(*) FROM raffle_entries WHERE install_id = '11111111-1111-1111-1111-111111111111';")"
[[ "$entry_count" == 2 ]] || { printf 'Expected separate production/test entries, got %s\n' "$entry_count" >&2; exit 1; }
printf 'PASS separate production/test registrations\n'
legacy_fields="$(docker exec "$container_name" mariadb -N -u integration_user --password=integration-db-password raffle_integration -e "SELECT COUNT(*) FROM raffle_entries WHERE install_id = '11111111-1111-1111-1111-111111111111' AND challenge_count_at_consent = 0 AND is_perfect_so_far = 0;")"
[[ "$legacy_fields" == 2 ]] || { printf 'New-season registrations persisted legacy consent fields.\n' >&2; exit 1; }
printf 'PASS new-season registrations ignore legacy consent fields\n'

docker exec "$container_name" mariadb -u integration_user --password=integration-db-password raffle_integration -e "
INSERT INTO raffle_entries (season_id, install_id, email, terms_version, contact_consent, age_confirmed, consent_at, badge_count_at_consent, challenge_count_at_consent, is_perfect_so_far) VALUES
('local-draw-test', '22222222-2222-2222-2222-222222222222', 'eligible@example.test', 'integration-v1', 1, 1, NOW(), 0, 0, 0),
('local-draw-test', '33333333-3333-3333-3333-333333333333', 'wrong-season@example.test', 'integration-v1', 1, 1, NOW(), 12, 12, 1);
INSERT INTO analytics_events (install_id, season_id, event_type, event_time, badge_count_after_event) VALUES
('22222222-2222-2222-2222-222222222222', 'local-draw-test', 'badge_claimed', '2020-05-01 18:00:00', 3),
('33333333-3333-3333-3333-333333333333', 'local-open-production', 'badge_claimed', '2020-05-01 18:00:00', 12);"

draw_body="$tmp_dir/draw.json"
draw_status="$(curl --silent --show-error --output "$draw_body" --write-out '%{http_code}' --request POST --user 'integration-admin:integration-dashboard-password' --header 'Content-Type: application/json' --data '{"season_id":"local-draw-test","count":10,"min_badges":2}' "http://127.0.0.1:$http_port/draw.php")"
[[ "$draw_status" == 200 ]] || { printf 'draw failed with HTTP %s\n' "$draw_status" >&2; exit 1; }
"$php_bin" -r '$data=json_decode(file_get_contents($argv[1]), true); $winner=$data["winners"][0]["install_id"] ?? null; exit(($data["eligible_total"] ?? null) === 1 && $winner === "22222222-2222-2222-2222-222222222222" ? 0 : 1);' "$draw_body" \
    || { printf 'Draw included a cross-season event or consent counter.\n' >&2; exit 1; }
printf 'PASS seasonal analytics determine draw eligibility\n'
printf 'Integration test passed. The MariaDB container and all fixture data will now be removed.\n'
