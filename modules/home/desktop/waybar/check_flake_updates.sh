#!/usr/bin/env bash

# CONFIGURATION
FLAKE_DIR="$HOME/dotfiles"
STATE_FILE="/tmp/waybar_flake_state"

# 1. Validation
if [ ! -d "$FLAKE_DIR" ]; then
    echo "{\"text\": \"Err\", \"tooltip\": \"Flake directory not found\", \"class\": \"critical\"}"
    exit 1
fi

# 2. Prepare Sandbox (The "Dry Run" Replacement)
# We copy the flake to a temp dir so we can actually "write" the lockfile there
# without affecting your real config.
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Copy files (using rsync or cp)
# We exclude .git to speed it up, but copy everything else in case of relative imports
if command -v rsync &> /dev/null; then
    rsync -a --exclude '.git' "$FLAKE_DIR/" "$TEMP_DIR/"
else
    cp -r "$FLAKE_DIR/." "$TEMP_DIR/"
fi

# 3. Run Update in Sandbox
# We switch to the temp dir and run the standard update command.
# We capture Standard Error (2>&1) because that's where Nix prints update logs.
cd "$TEMP_DIR" || exit 1
OUTPUT=$(nix flake update 2>&1)

# 4. Parse Output
UPDATED_NAMES=$(echo "$OUTPUT" | grep "Updated input" | awk -F"'" '{print $2}')

if [ -z "$UPDATED_NAMES" ]; then
    UPDATE_COUNT=0
else
    UPDATE_COUNT=$(echo "$UPDATED_NAMES" | wc -w)
fi

TOOLTIP=$(echo "$UPDATED_NAMES" | tr '\n' '\r')

# 5. Notifications (Same logic as before)
CURRENT_SIG="$UPDATE_COUNT-$UPDATED_NAMES"
PREV_SIG=$(cat "$STATE_FILE" 2>/dev/null)

if [ "$CURRENT_SIG" != "$PREV_SIG" ] && [ "$UPDATE_COUNT" -gt 0 ]; then
    if echo "$UPDATED_NAMES" | grep -qw "nixpkgs"; then
        notify-send -u critical \
                    -i software-update-available \
                    "Flake Update Available" \
                    "Inputs: $TOOLTIP"
    else
        notify-send -u normal \
                    -i package-x-generic \
                    "Flake Update Available" \
                    "Inputs: $TOOLTIP"
    fi
    echo "$CURRENT_SIG" > "$STATE_FILE"
fi

if [ "$UPDATE_COUNT" -eq 0 ]; then
    echo "clean" > "$STATE_FILE"
fi

# 6. JSON Output for Waybar
if [ "$UPDATE_COUNT" -gt 0 ]; then
    if echo "$UPDATED_NAMES" | grep -qw "nixpkgs"; then
        echo "{\"text\": \"$UPDATE_COUNT\", \"tooltip\": \"$TOOLTIP\", \"class\": \"updates-nixpkgs\"}"
    else
        echo "{\"text\": \"$UPDATE_COUNT\", \"tooltip\": \"$TOOLTIP\", \"class\": \"updates\"}"
    fi
else
    echo "{\"text\": \"\", \"tooltip\": \"System up to date\", \"class\": \"clean\"}"
fi
