#!/usr/bin/env bash
set -euo pipefail

read -r -s -p 'App-Token: ' raffle_test_token
printf '\n'
trap 'unset raffle_test_token' EXIT

raffle_endpoint='https://api.derbergschein.de/raffle.php'

check_raffle() {
    local label="$1"
    local payload="$2"
    printf '%s\n' "$label"
    printf 'header = "X-App-Token: %s"\n' "$raffle_test_token" | curl --config - \
        --silent --show-error --max-time 10 \
        --request POST \
        --header 'Content-Type: application/json' \
        --data "$payload" \
        --write-out '\nHTTP %{http_code}\n' \
        "$raffle_endpoint"
}

# Each request deliberately omits install_id, email, and consent. Even if a
# registration were unexpectedly open, validation prevents a database write.
check_raffle '2027 Produktion (erwartet: registration_closed / 403)' '{"season_id":"bergschein-2027"}'
check_raffle '2027 Testmodus (erwartet: registration_closed / 403)' '{"season_id":"test-bergschein-2027"}'
check_raffle 'Unbekannte Saison (erwartet: invalid_season_id / 422)' '{"season_id":"unknown-season"}'
check_raffle 'Alter Client ohne Saison (erwartet: registration_closed / 403)' '{}'
