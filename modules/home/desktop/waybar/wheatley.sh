#!/usr/bin/env bash

# Homelab summary from Wheatley's dashboard API (svcctl and hostctl). Reads
# only: those GETs need no login, just the X-Svcctl header.

ICON="󰒋"
# Tile name -> hostctl's name for the host
HOSTS=("Wheatley:wheatley" "Chell:chell" "GLaDOS:GLaDOS" "Companion Cube:CompanionCube")

# The short MagicDNS name only resolves on the tailnet; otherwise mDNS.
if [ "$(tailscale status --peers=false --json 2> /dev/null | jq -r '.BackendState' 2> /dev/null)" = "Running" ]; then
    base="http://wheatley"
else
    base="http://wheatley.local"
fi

format_uptime() {
    local seconds=${1%.*}
    if ((seconds >= 86400)); then
        echo "$((seconds / 86400))d $((seconds % 86400 / 3600))h"
    elif ((seconds >= 3600)); then
        echo "$((seconds / 3600))h $((seconds % 3600 / 60))m"
    else
        echo "$((seconds / 60))m"
    fi
}

# Empty text hides the module while the homelab isn't reachable
if ! status=$(curl -fs -m 3 -H 'X-Svcctl: 1' "$base/api/svc/status") || [ -z "$status" ]; then
    echo '{"text": ""}'
    exit 0
fi

up=0
lines=()
for entry in "${HOSTS[@]}"; do
    tile=${entry%%:*}
    host=${entry##*:}
    state=$(jq -r --arg tile "$tile" '.tiles[$tile] // "unknown"' <<< "$status")
    if [ "$state" != "up" ]; then
        lines+=("○ $tile")
        continue
    fi
    up=$((up + 1))
    ping=$(jq -r --arg tile "$tile" '.ping[$tile] // empty | round' <<< "$status")
    uptime=$(curl -fs -m 3 "$base/api/hosts/$host" | jq -r '.uptime // empty')
    line="● $tile"
    [ -n "$ping" ] && line+="  ${ping} ms"
    [ -n "$uptime" ] && line+="  $(format_uptime "$uptime")"
    lines+=("$line")
done

total=${#HOSTS[@]}
class="ok"
((up < total)) && class="partial"
((up == 0)) && class="down"
# A failed dotfiles-switch outranks the host count
jq -e '.switch | to_entries | any(.value == "failed")' <<< "$status" > /dev/null && class="failed"

tooltip=$(printf '%s\n' "${lines[@]}")
jq -cn --arg text "$ICON $up/$total" --arg class "$class" --arg tooltip "$tooltip" \
    '{text: $text, class: $class, tooltip: ($tooltip | gsub("&"; "&amp;") | gsub("<"; "&lt;"))}'
