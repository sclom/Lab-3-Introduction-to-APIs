#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$PROJECT_ROOT/logs/lab3.log"
DATA_DIR="$PROJECT_ROOT/data"

DAD_JOKE_URL="https://icanhazdadjoke.com/"
DAD_JOKE_JSON="$DATA_DIR/dad_joke.json"
DAD_JOKE_TXT="$DATA_DIR/dad_joke.txt"
DECK_CREATE_URL="https://deckofcardsapi.com/api/deck/new/shuffle/?deck_count=1"
DECK_CREATE_JSON="$DATA_DIR/deck_create.json"
DECK_DRAW_JSON="$DATA_DIR/deck_draw.json"
DECK_SUMMARY_TXT="$DATA_DIR/deck_summary.txt"

mkdir -p "$PROJECT_ROOT/logs" "$DATA_DIR"

log() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '[%s] %s\n' "$timestamp" "$1" >> "$LOG_FILE"
}

cleanup() {
    local exit_code=$?
    trap - EXIT
    log "[LAB3_END]"
    if (( exit_code == 0 )); then
        log "Cleanup complete."
    else
        log "Cleanup after failure (exit code $exit_code)."
    fi
}
trap cleanup EXIT

log "[LAB3_START]"

for prerequisite in curl jq; do
    if ! command -v "$prerequisite" >/dev/null 2>&1; then
        log "[PREREQUISITE_FAIL] Required command not found: $prerequisite"
        exit 1
    fi
done

log "[BASH_OK] Prerequisites validated. Starting API lab."

if DAD_JOKE_HTTP_STATUS="$(curl -sS -H 'Accept: application/json' -w '%{http_code}' -o "$DAD_JOKE_JSON" "$DAD_JOKE_URL")"; then
    :
else
    log "[CURL_JOKE_FAIL] Request failed (HTTP status ${DAD_JOKE_HTTP_STATUS:-000})."
    exit 1
fi

if [[ "$DAD_JOKE_HTTP_STATUS" != "200" ]]; then
    log "[CURL_JOKE_FAIL] HTTP status $DAD_JOKE_HTTP_STATUS."
    exit 1
fi
log "[CURL_JOKE_OK]"

if jq -r '.id, .joke' "$DAD_JOKE_JSON" > "$DAD_JOKE_TXT"; then
    log "[JQ_JOKE_OK]"
else
    log "[JQ_JOKE_FAIL] Could not parse dad joke response."
    exit 1
fi

if DECK_CREATE_STATUS="$(curl -sS -H 'Accept: application/json' -w '%{http_code}' -o "$DECK_CREATE_JSON" "$DECK_CREATE_URL")"; then
    :
else
    log "[DECK_CREATE_FAIL] Request failed (HTTP status ${DECK_CREATE_STATUS:-000})."
    exit 1
fi

if [[ "$DECK_CREATE_STATUS" != "200" ]]; then
    log "[DECK_CREATE_FAIL] HTTP status $DECK_CREATE_STATUS."
    exit 1
fi
log "[DECK_CREATE_OK]"

if DECK_ID="$(jq -r '.deck_id' "$DECK_CREATE_JSON")" && [[ -n "$DECK_ID" && "$DECK_ID" != "null" ]]; then
    :
else
    log "[JQ_DECK_FAIL] Could not extract deck_id."
    exit 1
fi

DECK_DRAW_URL="https://deckofcardsapi.com/api/deck/$DECK_ID/draw/?count=2"
if DECK_DRAW_STATUS="$(curl -sS -H 'Accept: application/json' -w '%{http_code}' -o "$DECK_DRAW_JSON" "$DECK_DRAW_URL")"; then
    :
else
    log "[DECK_DRAW_FAIL] Request failed (HTTP status ${DECK_DRAW_STATUS:-000})."
    exit 1
fi

if [[ "$DECK_DRAW_STATUS" != "200" ]]; then
    log "[DECK_DRAW_FAIL] HTTP status $DECK_DRAW_STATUS."
    exit 1
fi
log "[DECK_DRAW_OK]"

if jq -r '.cards[] | "\(.value) of \(.suit)"' "$DECK_DRAW_JSON" > "$DECK_SUMMARY_TXT" &&
    jq -r '"Remaining: \(.remaining)"' "$DECK_DRAW_JSON" >> "$DECK_SUMMARY_TXT"; then
    log "[JQ_DECK_OK]"
else
    log "[JQ_DECK_FAIL] Could not parse deck draw response."
    exit 1
fi
