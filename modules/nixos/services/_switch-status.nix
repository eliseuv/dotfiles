# switch-status: dotfiles-switch.service's state as one JSON object, for the
# homelab dashboard's switch buttons (svcctl in homelab/dashboard/controls.nix).
# Run there directly on the dashboard host, and on others through the
# remote-control forced command (services/remote-control.nix).
#
#   {"ActiveState", "Result", "InvocationID", "last"}
#
# `last` is the status the unit keeps of its latest run in its StateDirectory
# (services/dotfiles-switch.nix): the stage it got to and, once over, its
# result, the reason it failed and the generation's tag. null before any run.
# A run is told apart by its InvocationID while systemd has the unit loaded,
# and by `last.invocation` once it unloads the inactive unit, which also
# resets Result to success: a failed run is only known from `last`.
#
# dotfiles-home-switch.service shares that status (`last.kind` says which
# ran), so the unit shown is whichever is running, else the one whose run
# `last` is. Else that unit is unloaded, so it's shown as such, never the
# other's older run; with no `last` at all, dotfiles-switch.service.
{
  pkgs,
  systemd,
}:
pkgs.writeShellApplication {
  name = "switch-status";
  runtimeInputs = [
    pkgs.jq
    systemd
  ];
  text = ''
    status=/var/lib/dotfiles-switch/status.json
    show() {
      systemctl show --property=ActiveState,Result,InvocationID "$1" \
        | jq --raw-input --null-input '[inputs | capture("^(?<key>[^=]+)=(?<value>.*)$")] | from_entries'
    }
    jq --null-input \
      --argjson system "$(show dotfiles-switch.service)" \
      --argjson home "$(show dotfiles-home-switch.service)" \
      --slurpfile last <(cat "$status" 2>/dev/null || true) \
      '[$system, $home] as $units
        | ($units | map(select(.ActiveState | IN("activating", "active", "deactivating"))) | first)
          // ($units | map(select(.InvocationID != "" and .InvocationID == $last[0].invocation?)) | first)
          // (if $last[0] then {ActiveState: "inactive", Result: "success", InvocationID: ""} else $system end)
        | . + {last: $last[0]}'
  '';
}
