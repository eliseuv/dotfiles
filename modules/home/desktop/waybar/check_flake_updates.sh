#!/usr/bin/env bash
# Waybar module: count flake inputs with pending updates.
#
# The check (a full `nix flake update` in a throwaway copy) fetches every
# input, so it runs at most once per CHECK_INTERVAL. Waybar polls often and
# gets the cached result in between. The cache lives in XDG_CACHE_HOME, not
# /tmp, so the spacing survives a reboot.
#
# --refresh drops the cache and signals waybar to re-run this now (after an
# upgrade, so the count clears straight away).

FLAKE_DIR="$HOME/dotfiles"
CHECK_INTERVAL=$((8 * 60 * 60))
SIGNAL=8
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-flake"
OUTPUT_FILE="$CACHE_DIR/output.json"
STATE_FILE="$CACHE_DIR/notified"

if [ "${1:-}" = "--refresh" ]; then
    rm -f "$OUTPUT_FILE"
    pkill -RTMIN+"$SIGNAL" waybar
    exit 0
fi

mkdir -p "$CACHE_DIR"

if [ -f "$OUTPUT_FILE" ] && [ $(($(date +%s) - $(stat -c %Y "$OUTPUT_FILE"))) -lt "$CHECK_INTERVAL" ]; then
    cat "$OUTPUT_FILE"
    exit 0
fi

if [ ! -d "$FLAKE_DIR" ]; then
    echo '{"text": "Err", "tooltip": "Flake directory not found", "class": "critical"}'
    exit 1
fi

# Update a copy, so the real lock file is never touched. .git is left out
# for speed; everything else is copied in case of relative imports.
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
if command -v rsync &> /dev/null; then
    rsync -a --exclude '.git' "$FLAKE_DIR/" "$TEMP_DIR/"
else
    cp -r "$FLAKE_DIR/." "$TEMP_DIR/"
fi

# Nix prints the update log on stderr.
if ! OUTPUT=$(cd "$TEMP_DIR" && nix flake update 2>&1); then
    # Not cached: a failure (usually offline) is retried on the next poll
    # rather than shown, or mistaken for "up to date", for 8h.
    echo '{"text": "!", "tooltip": "Flake update check failed", "class": "critical"}'
    exit 0
fi

UPDATED_NAMES=$(echo "$OUTPUT" | grep "Updated input" | awk -F"'" '{print $2}')
if [ -z "$UPDATED_NAMES" ]; then
    UPDATE_COUNT=0
else
    UPDATE_COUNT=$(echo "$UPDATED_NAMES" | wc -w)
fi
TOOLTIP=$(echo "$UPDATED_NAMES" | tr '\n' '\r')

# Notify once per distinct set of pending updates.
CURRENT_SIG="$UPDATE_COUNT-$UPDATED_NAMES"
PREV_SIG=$(cat "$STATE_FILE" 2>/dev/null)
if [ "$CURRENT_SIG" != "$PREV_SIG" ] && [ "$UPDATE_COUNT" -gt 0 ]; then
    if echo "$UPDATED_NAMES" | grep -qw "nixpkgs"; then
        notify-send -u critical -i software-update-available \
            "Flake Update Available" "Inputs: $TOOLTIP"
    else
        notify-send -u normal -i package-x-generic \
            "Flake Update Available" "Inputs: $TOOLTIP"
    fi
    echo "$CURRENT_SIG" > "$STATE_FILE"
fi
if [ "$UPDATE_COUNT" -eq 0 ]; then
    echo "clean" > "$STATE_FILE"
fi

if [ "$UPDATE_COUNT" -gt 0 ]; then
    if echo "$UPDATED_NAMES" | grep -qw "nixpkgs"; then
        CLASS=updates-nixpkgs
    else
        CLASS=updates
    fi
    RESULT="{\"text\": \"$UPDATE_COUNT\", \"tooltip\": \"$TOOLTIP\", \"class\": \"$CLASS\"}"
else
    RESULT='{"text": "", "tooltip": "System up to date", "class": "clean"}'
fi

# Written atomically, so a concurrent poll never reads half a file.
echo "$RESULT" > "$OUTPUT_FILE.tmp" && mv -f "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
echo "$RESULT"
