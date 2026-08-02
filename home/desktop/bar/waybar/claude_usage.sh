#!/usr/bin/env bash

# CONFIGURATION
CREDS_FILE="$HOME/.claude/.credentials.json"
CACHE_FILE="/tmp/waybar_claude_usage_cache.json"
LOCK_FILE="/tmp/waybar_claude_usage.lock"
FETCH_LOCK_FILE="/tmp/waybar_claude_usage_fetch.lock"
CACHE_TTL=300 # seconds; the usage endpoint is undocumented and aggressively rate-limited
REFRESH_BUFFER=300 # refresh token if it expires within this many seconds
CLIENT_ID="9d1c250a-e61b-44d9-88ed-5944d1962f5e" # Claude CLI OAuth client ID
TOKEN_URL="https://platform.claude.com/v1/oauth/token"
USAGE_URL="https://api.anthropic.com/api/oauth/usage"

die() {
    jq -nc --arg t "$1" --arg tip "$2" '{text: $t, tooltip: $tip, class: "critical"}'
    exit 0
}

if [ ! -f "$CREDS_FILE" ]; then
    die "" "Not logged in to Claude Code (~/.claude/.credentials.json not found)"
fi

# 1. Load credentials, refreshing the access token first if it's near/past expiry.
(
    flock -w 10 200 || exit 0

    creds=$(cat "$CREDS_FILE")
    access_token=$(jq -r '.claudeAiOauth.accessToken // empty' <<< "$creds")
    refresh_token=$(jq -r '.claudeAiOauth.refreshToken // empty' <<< "$creds")
    expires_at=$(jq -r '.claudeAiOauth.expiresAt // 0' <<< "$creds")

    now_ms=$(($(date +%s) * 1000))

    if [ -n "$refresh_token" ] && [ $((expires_at - now_ms)) -lt $((REFRESH_BUFFER * 1000)) ]; then
        refresh_body=$(jq -nc --arg ci "$CLIENT_ID" --arg rt "$refresh_token" \
            '{grant_type: "refresh_token", client_id: $ci, refresh_token: $rt}')

        resp=$(curl -s --max-time 10 -X POST "$TOKEN_URL" \
            -H "Content-Type: application/json" \
            -H "anthropic-beta: oauth-2025-04-20" \
            --data "$refresh_body") || resp=""

        new_access_token=$(jq -r '.access_token // empty' <<< "$resp" 2>/dev/null)

        if [ -n "$new_access_token" ]; then
            new_refresh_token=$(jq -r '.refresh_token // empty' <<< "$resp")
            expires_in=$(jq -r '.expires_in // 0' <<< "$resp")
            new_expires_at=$(( $(date +%s) * 1000 + expires_in * 1000 ))

            tmp=$(mktemp)
            jq --arg at "$new_access_token" \
               --arg rt "${new_refresh_token:-$refresh_token}" \
               --argjson ea "$new_expires_at" \
               '.claudeAiOauth.accessToken = $at | .claudeAiOauth.refreshToken = $rt | .claudeAiOauth.expiresAt = $ea' \
               "$CREDS_FILE" > "$tmp" && mv "$tmp" "$CREDS_FILE"
        fi
    fi
) 200>"$LOCK_FILE"

# 2. Serve from cache if still fresh.
if [ -f "$CACHE_FILE" ]; then
    cache_age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE")))
    if [ "$cache_age" -lt "$CACHE_TTL" ]; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# 3. Fetch usage, serializing concurrent instances (e.g. one per output on a
# multi-monitor setup) so only one of them ever hits the rate-limited API;
# the rest block here and then serve the cache the winner just wrote.
{
    flock -w 15 202 || die "⚠" "Failed to acquire usage fetch lock"

    # Re-check: another instance may have refreshed the cache while we waited.
    if [ -f "$CACHE_FILE" ]; then
        cache_age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE")))
        if [ "$cache_age" -lt "$CACHE_TTL" ]; then
            cat "$CACHE_FILE"
            exit 0
        fi
    fi

    access_token=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS_FILE")
    if [ -z "$access_token" ]; then
        die "" "No Claude access token available"
    fi

    usage=$(curl -s --max-time 10 -w '\n%{http_code}' "$USAGE_URL" \
        -H "Authorization: Bearer $access_token" \
        -H "anthropic-beta: oauth-2025-04-20") || usage=""

    http_code=$(tail -n1 <<< "$usage")
    body=$(sed '$d' <<< "$usage")

    if [ "$http_code" != "200" ] || ! jq -e . <<< "$body" &> /dev/null; then
        if [ -f "$CACHE_FILE" ]; then
            cat "$CACHE_FILE"
            exit 0
        fi
        die "⚠" "Failed to fetch Claude usage (HTTP $http_code)"
    fi

# 4. Parse session (5h) and weekly (7d) utilization + reset times.
session_pct=$(jq -r '(.five_hour.utilization // 0) | round' <<< "$body")
session_reset=$(jq -r '.five_hour.resets_at // empty' <<< "$body")
weekly_pct=$(jq -r '(.seven_day.utilization // 0) | round' <<< "$body")
weekly_reset=$(jq -r '.seven_day.resets_at // empty' <<< "$body")

fmt_reset() {
    [ -n "$1" ] && date -d "$1" "+%a %H:%M" 2> /dev/null
}

fmt_reset_short() {
    [ -n "$1" ] && date -d "$1" "+%H:%M" 2> /dev/null
}

color_for_pct() {
    local pct=$1
    if [ "$pct" -ge 90 ]; then
        echo "#f38ba8"
    elif [ "$pct" -ge 70 ]; then
        echo "#e5c07b"
    fi
}

span_section() {
    local pct=$1
    local section=$2
    local color
    color=$(color_for_pct "$pct")
    if [ -n "$color" ]; then
        echo "<span color='${color}'>${section}</span>"
    else
        echo "${section}"
    fi
}

session_reset_fmt=$(fmt_reset "$session_reset")
weekly_reset_fmt=$(fmt_reset "$weekly_reset")
session_reset_short=$(fmt_reset_short "$session_reset")

max_pct=$session_pct
[ "$weekly_pct" -gt "$max_pct" ] && max_pct=$weekly_pct

class="normal"
[ "$max_pct" -ge 70 ] && class="warning"
[ "$max_pct" -ge 90 ] && class="critical"

session_section="󰚩    ${session_pct}%$( [ -n "$session_reset_short" ] && echo " (${session_reset_short})")"
weekly_section="󰃭 ${weekly_pct}%$( [ -n "$weekly_reset_fmt" ] && echo " (${weekly_reset_fmt})")"
session_span=$(span_section "$session_pct" "$session_section")
weekly_span=$(span_section "$weekly_pct" "$weekly_section")
updated_at=$(date "+%a %H:%M")

text="${session_span}   ${weekly_span}"
tooltip="Last updated: ${updated_at}"

output=$(jq -nc --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" \
    '{text: $text, tooltip: $tooltip, class: $class}')

tmp=$(mktemp)
echo "$output" > "$tmp" && mv "$tmp" "$CACHE_FILE"

echo "$output"
} 202>"$FETCH_LOCK_FILE"
