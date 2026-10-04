# Start/stop/restart buttons on dashboard tiles whose registry entry names a
# systemd unit (`homelab.services.<name>.dashboard.unit`). svcctl.py serves
# the API on loopback behind the dashboard's nginx, so it shares the
# dashboard's reach (LAN + tailnet) and has no login of its own. It runs
# unprivileged; polkit lets it manage exactly the listed units, nothing else.
# Tiles with `dashboard.wake` instead get a wake button, which sends a
# Wake-on-LAN packet to that host (one of `my.wakeOnLan.hosts`), and an
# up/down state from pinging it over mDNS. With `dashboard.poweroff` they also
# get a power-off button, which logs in to the host over SSH with a key whose
# only use there is a forced `shutdown +1` (services/remote-poweroff.nix).
# Tiles with `dashboard.reboot` stand for this host itself and get a reboot
# button, which reboots it at once; polkit lets svcctl do that and no more.
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

  wakeTiles = lib.filterAttrs (
    _: service: service.dashboard != null && service.dashboard.wake != null
  ) config.homelab.services;
  # Tile name -> {mac, host, poweroff}.
  wakeable = lib.mapAttrs' (
    _: service:
    let
      host = service.dashboard.wake;
    in
    lib.nameValuePair service.dashboard.name {
      mac = config.my.wakeOnLan.hosts.${host};
      host = "${host}.local";
      inherit (service.dashboard) poweroff;
    }
  ) wakeTiles;
  wakeFile = pkgs.writeText "svcctl-wake.json" (builtins.toJSON wakeable);

  rebootTiles = lib.mapAttrsToList (_: service: service.dashboard.name) (
    lib.filterAttrs (
      _: service: service.dashboard != null && service.dashboard.reboot
    ) config.homelab.services
  );
  rebootFile = pkgs.writeText "svcctl-reboot.json" (builtins.toJSON rebootTiles);
  canReboot = rebootTiles != [ ];

  poweroffKey = "svcctl/poweroff-ssh-key";
  canPoweroff = lib.any (service: service.dashboard.poweroff) (lib.attrValues wakeTiles);
in
{

  config = lib.mkIf config.my.homelab.enable {

    assertions =
      lib.mapAttrsToList (name: service: {
        assertion = config.my.wakeOnLan.hosts ? ${service.dashboard.wake};
        message = "homelab.services.${name}.dashboard.wake: ${service.dashboard.wake} is not in my.wakeOnLan.hosts";
      }) wakeTiles
      ++ lib.mapAttrsToList (name: service: {
        assertion = !service.dashboard.poweroff || service.dashboard.wake != null;
        message = "homelab.services.${name}.dashboard.poweroff needs dashboard.wake";
      }) (lib.filterAttrs (_: service: service.dashboard != null) config.homelab.services)
      ++ lib.mapAttrsToList (name: service: {
        assertion = service.dashboard.terminal == null || service.dashboard.wake != null;
        message = "homelab.services.${name}.dashboard.terminal needs dashboard.wake";
      }) (lib.filterAttrs (_: service: service.dashboard != null) config.homelab.services)
      # controls.js builds one kind of button bar per tile.
      ++ lib.mapAttrsToList (name: service: {
        assertion =
          !service.dashboard.reboot || (service.dashboard.unit == null && service.dashboard.wake == null);
        message = "homelab.services.${name}.dashboard.reboot can't be combined with dashboard.unit or dashboard.wake";
      }) (lib.filterAttrs (_: service: service.dashboard != null) config.homelab.services);

    users.users.svcctl = {
      isSystemUser = true;
      group = "svcctl";
    };
    users.groups.svcctl = { };

    # The target's host key must be in programs.ssh.knownHosts: svcctl runs
    # ssh with StrictHostKeyChecking and no known_hosts of its own.
    sops.secrets.${poweroffKey} = lib.mkIf canPoweroff { owner = "svcctl"; };

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
    ''
    # Same three actions as remote-poweroff.nix grants for power-off, for the
    # same reasons: someone is usually logged in, and sessions hold inhibitors.
    + lib.optionalString canReboot ''
      polkit.addRule(function (action, subject) {
        var actions = [
          "org.freedesktop.login1.reboot",
          "org.freedesktop.login1.reboot-multiple-sessions",
          "org.freedesktop.login1.reboot-ignore-inhibit",
        ];
        if (subject.user == "svcctl" && actions.indexOf(action.id) >= 0) {
          return polkit.Result.YES;
        }
      });
    '';

    systemd.services.svcctl = {
      description = "Dashboard service controls";
      wantedBy = [ "multi-user.target" ];
      path = [
        config.systemd.package
        pkgs.iputils
        pkgs.openssh
      ];
      serviceConfig = {
        ExecStart = lib.concatStringsSep " " (
          [
            (lib.getExe pkgs.python3)
            "${./svcctl.py}"
            (toString port)
            "${unitsFile}"
            "${wakeFile}"
            "${rebootFile}"
          ]
          ++ lib.optional canPoweroff config.sops.secrets.${poweroffKey}.path
        );
        User = "svcctl";
        Group = "svcctl";
        Restart = "on-failure";
        # Talks to systemd over D-Bus (AF_UNIX), serves on loopback, and
        # broadcasts wake packets and pings (unprivileged ICMP) and SSHes to
        # power hosts off on the LAN.
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
