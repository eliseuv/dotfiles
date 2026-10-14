#!/usr/bin/env bash

# Usage: bitwarden.sh [status|search|lock]
# rbw-agent holds the unlocked keys and locks itself after lock_timeout, so
# this only reads its state; every prompt (master password, email code, API
# key) goes through rbw's pinentry, so no terminal is needed.

ICON="󰞀"
ICON_LOCKED="󰌾"
SIGNAL=11 # must match "signal" of custom/bitwarden in modules.json
ROFI_THEME="$HOME/.config/rofi/config/askpass.rasi"

show_msg() {
    rofi -theme "$ROFI_THEME" -e "$1"
}

refresh_bar() {
    pkill -RTMIN+"$SIGNAL" waybar
}

# rbw only writes its local vault copy on login and removes it on logout
vault_db() {
    compgen -G "${XDG_CACHE_HOME:-$HOME/.cache}/rbw/*.json" | head -n 1
}

print_status() {
    if ! command -v rbw &> /dev/null; then
        # Empty text hides the module
        echo '{"text": ""}'
        return
    fi

    local db email state sync=""
    db=$(vault_db)
    email=$(rbw config show 2> /dev/null | jq -r '.email // empty')
    [ -n "$db" ] && sync=$(date -r "$db" '+%F %R')

    if rbw unlocked &> /dev/null; then
        state=unlocked
    elif [ -n "$db" ]; then
        state=locked
    else
        state=logged-out
    fi

    jq -cn --arg state "$state" --arg email "$email" --arg sync "$sync" \
        --arg icon "$ICON" --arg locked "$ICON_LOCKED" '
        (if $email != "" then "Account: \($email | @html)\n" else "" end) as $account
        | (if $sync != "" then "Last sync: \($sync)\n" else "" end) as $synced
        | if $state == "unlocked" then
            {text: $icon, class: "unlocked", tooltip: "Bitwarden unlocked\n\($account)\($synced)\nClick to search\nRight-click to lock"}
          elif $state == "locked" then
            {text: $locked, class: "locked", tooltip: "Bitwarden locked\n\($account)\($synced)\nClick to unlock and search"}
          else
            {text: $locked, class: "logged-out", tooltip: "Bitwarden logged out\n\nClick to log in"}
          end
    '
}

# Runs an rbw command, surfacing its error unless the prompt was dismissed
run() {
    local out
    out=$(rbw "$@" 2>&1) && return
    [[ "$out" != *"pinentry cancelled"* ]] && show_msg "Bitwarden: $out"
    return 1
}

login() {
    local out
    if ! out=$(rbw login 2>&1); then
        # bitwarden.com rejects password logins from unknown devices until
        # they are registered with the account's personal API key, once per
        # device. rbw 1.15 only maps the old captcha response to "run rbw
        # register"; the newer "New device verification required" reaches us
        # as a bare 400, so that triggers registration too
        if [[ "$out" == *"rbw register"* || "$out" == *"error: 400"* ]]; then
            run register && run login
        else
            [[ "$out" != *"pinentry cancelled"* ]] && show_msg "Bitwarden: $out"
            false
        fi
    fi
}

search() {
    command -v rbw &> /dev/null || return
    if [ -z "$(vault_db)" ]; then
        login
        refresh_bar
        return
    fi
    # Unlock first so the bar reflects it and a failure gets its own message
    # instead of rofi-rbw's
    run unlock || return
    refresh_bar
    rofi-rbw
}

case "${1:-status}" in
    status) print_status ;;
    search) search ;;
    lock)
        rbw lock &> /dev/null
        refresh_bar
        ;;
    *)
        echo "Usage: $0 [status|search|lock]" >&2
        exit 1
        ;;
esac
