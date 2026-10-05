{ config, lib, ... }:
let
  cfg = config.my.services.tailscale;
in
{

  config = lib.mkIf cfg.enable {

    services.tailscale = {
      enable = true;
      # Lets the user run `tailscale up/down` without root (used by the waybar toggle)
      extraSetFlags = [ "--operator=${config.my.host.primaryUser}" ];
    };

    # `tailscale down` (waybar, the dashboard) persists across reboots, so a
    # host that must stay reachable is brought back up at boot.
    systemd.services.tailscale-up-at-boot = lib.mkIf cfg.upAtBoot {
      description = "Bring Tailscale up at boot";
      after = [ "tailscaled.service" ];
      requires = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        # Bounded so a node that needs a login can't hang the unit. `up` as
        # root refuses unless it repeats every non-default setting, i.e. the
        # operator from extraSetFlags.
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe config.services.tailscale.package)
            "up"
            "--timeout=60s"
          ]
          ++ config.services.tailscale.extraSetFlags
        );
      };
    };

  };

}
