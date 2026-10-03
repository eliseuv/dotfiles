# Start/stop/restart buttons on dashboard tiles whose registry entry names a
# systemd unit (`homelab.services.<name>.dashboard.unit`). svcctl.py serves
# the API on loopback behind the dashboard's nginx, so it shares the
# dashboard's reach (LAN + tailnet) and has no login of its own. It runs
# unprivileged; polkit lets it manage exactly the listed units, nothing else.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  port = 8099;

  controlled = lib.filterAttrs (
    _: service: service.dashboard != null && service.dashboard.unit != null
  ) config.homelab.services;
  # Tile name -> unit; the API addresses units by the name on the tile.
  units = lib.mapAttrs' (
    _: service: lib.nameValuePair service.dashboard.name service.dashboard.unit
  ) controlled;
  unitsFile = pkgs.writeText "svcctl-units.json" (builtins.toJSON units);
in
{

  config = lib.mkIf config.my.homelab.enable {

    users.users.svcctl = {
      isSystemUser = true;
      group = "svcctl";
    };
    users.groups.svcctl = { };

    security.polkit.extraConfig = ''
      polkit.addRule(function (action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" && subject.user == "svcctl") {
          var units = ${builtins.toJSON (lib.attrValues units)};
          var verbs = ["start", "stop", "restart"];
          if (units.indexOf(action.lookup("unit")) >= 0 && verbs.indexOf(action.lookup("verb")) >= 0) {
            return polkit.Result.YES;
          }
        }
      });
    '';

    systemd.services.svcctl = {
      description = "Dashboard service controls";
      wantedBy = [ "multi-user.target" ];
      path = [ config.systemd.package ];
      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.python3} ${./svcctl.py} ${toString port} ${unitsFile}";
        User = "svcctl";
        Group = "svcctl";
        Restart = "on-failure";
        # Talks to systemd over D-Bus (AF_UNIX) and serves on loopback.
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
        ];
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        LockPersonality = true;
      };
    };

    services.nginx.virtualHosts.dashboard.locations."/api/svc/".proxyPass =
      "http://127.0.0.1:${toString port}";

  };

}
