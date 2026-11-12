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
    systemctl show --property=ActiveState,Result,InvocationID dotfiles-switch.service \
      | jq --raw-input --null-input \
        --slurpfile last <(cat "$status" 2>/dev/null || true) \
        '[inputs | capture("^(?<key>[^=]+)=(?<value>.*)$")] | from_entries + {last: $last[0]}'
  '';
}
