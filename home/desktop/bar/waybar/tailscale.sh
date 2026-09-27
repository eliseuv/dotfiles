#!/usr/bin/env bash

# Usage: tailscale.sh [status|toggle]
# Toggling without root requires this user to be the tailscale operator
# (see system/extra/tailscale.nix).

ICON="󰖂"
ICON_WARN="󰖂 "
SIGNAL=10 # must match "signal" of custom/tailscale in modules.json

status_json() {
    tailscale status --json 2> /dev/null
}

backend_state() {
    status_json | jq -r '.BackendState // empty'
}

print_status() {
    local status
    if ! command -v tailscale &> /dev/null || ! status=$(status_json) || [ -z "$status" ]; then
        # Empty text hides the module
        echo '{"text": ""}'
        return
    fi

    jq -c --arg icon "$ICON" --arg warn "$ICON_WARN" '
        .BackendState as $state
        | if $state == "Running" then
            ([.Peer[]? | select(.Online)] | map(.HostName | @html)) as $online
            | ([.Peer[]?] | length) as $total
            | ([.Peer[]? | select(.ExitNode) | .HostName] | first // null) as $exit
            | {
                text: "\($icon)  \(.Self.TailscaleIPs[0])",
                class: "connected",
                tooltip: (
                    "Tailnet: \(.CurrentTailnet.Name | @html)\n"
                    + "Host: \(.Self.HostName | @html)\n"
                    + "IPv4: \(.Self.TailscaleIPs[0])\n"
                    + (if $exit then "Exit node: \($exit | @html)\n" else "" end)
                    + "Peers online: \($online | length)/\($total)"
                    + (if ($online | length) > 0 then "\n  " + ($online | join("\n  ")) else "" end)
                    + "\n\nRight-click to disconnect"
                )
            }
          elif $state == "Stopped" then
            {text: $icon, class: "stopped", tooltip: "Tailscale off\n\nRight-click to connect"}
          elif $state == "NeedsLogin" or $state == "NeedsMachineAuth" then
            {text: $warn, class: "needs-login", tooltip: "Tailscale: \($state)\n\nClick to log in"}
          else
            {text: $icon, class: "stopped", tooltip: "Tailscale: \($state)"}
          end
    ' <<< "$status"
}

toggle() {
    case "$(backend_state)" in
        Running) tailscale down ;;
        # Login prints a URL that has to be opened, so it needs a terminal
        NeedsLogin | NeedsMachineAuth) kitty --hold tailscale up & ;;
        *) tailscale up ;;
    esac
    pkill -RTMIN+"$SIGNAL" waybar
}

case "${1:-status}" in
    status) print_status ;;
    toggle) toggle ;;
    *)
        echo "Usage: $0 [status|toggle]" >&2
        exit 1
        ;;
esac
