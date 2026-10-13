#!/usr/bin/env bash

# Usage: bitwarden.sh [status|toggle]
# bw only reports "unlocked" when handed a valid BW_SESSION, so the key from
# the last unlock is kept on tmpfs for this script (and shells) to reuse.

ICON="󰞀"
ICON_LOCKED="󰌾"
SIGNAL=11 # must match "signal" of custom/bitwarden in modules.json
SESSION_FILE="${XDG_RUNTIME_DIR:-/tmp}/bw-session"
ROFI_THEME="$HOME/.config/rofi/config/askpass.rasi"

load_session() {
    [ -r "$SESSION_FILE" ] && BW_SESSION=$(< "$SESSION_FILE") && export BW_SESSION
}

vault_status() {
    bw status --raw 2> /dev/null | jq -r '.status // empty'
}

show_msg() {
    rofi -theme "$ROFI_THEME" -e "$1"
}

print_status() {
    local status
    if ! command -v bw &> /dev/null || ! status=$(bw status --raw 2> /dev/null) || [ -z "$status" ]; then
        # Empty text hides the module
        echo '{"text": ""}'
        return
    fi

    jq -c --arg icon "$ICON" --arg locked "$ICON_LOCKED" '
        (if .userEmail then "Account: \(.userEmail | @html)\n" else "" end) as $account
        | (if .lastSync then "Last sync: \(.lastSync[0:16] | sub("T"; " "))\n" else "" end) as $sync
        | if .status == "unlocked" then
            {text: $icon, class: "unlocked", tooltip: "Bitwarden unlocked\n\($account)\($sync)\nClick to lock"}
          elif .status == "locked" then
            {text: $locked, class: "locked", tooltip: "Bitwarden locked\n\($account)\($sync)\nClick to unlock"}
          else
            {text: $locked, class: "logged-out", tooltip: "Bitwarden logged out\n\nClick to log in"}
          end
    ' <<< "$status"
}

unlock() {
    local password session
    password=$(rofi -dmenu -password -p "Master password" -theme "$ROFI_THEME" < /dev/null) || return
    [ -z "$password" ] && return
    # Via the environment so the password never shows up in argv
    if ! session=$(BW_PASSWORD="$password" bw unlock --raw --passwordenv BW_PASSWORD 2>&1); then
        show_msg "Unlock failed: $session"
        return
    fi
    (umask 077 && printf '%s' "$session" > "$SESSION_FILE")
    BW_SESSION="$session" bw sync &> /dev/null
}

toggle() {
    case "$(vault_status)" in
        unlocked)
            bw lock &> /dev/null
            rm -f "$SESSION_FILE"
            ;;
        locked) unlock ;;
        # Login asks for email and two-factor, so it needs a terminal
        *) "$TERMINAL" -e sh -c 'bw login; read -rp "Press Enter to close"' & ;;
    esac
    pkill -RTMIN+"$SIGNAL" waybar
}

load_session

case "${1:-status}" in
    status) print_status ;;
    toggle) toggle ;;
    *)
        echo "Usage: $0 [status|toggle]" >&2
        exit 1
        ;;
esac
