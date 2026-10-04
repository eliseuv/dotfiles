# Start/stop/restart buttons on dashboard tiles whose registry entry names a
# systemd unit (`homelab.services.<name>.dashboard.unit`). svcctl.py serves
# the API on loopback behind the dashboard's nginx, so it shares the
# dashboard's reach (LAN + tailnet). nginx puts every action (any non-GET)
# behind basic auth; reading the status stays open, like the dashboard. Over
# plain HTTP on the LAN the password crosses the wire in the clear; the
# tailnet encrypts it. svcctl runs unprivileged; polkit lets it manage exactly
# the listed units, nothing else.
# Tiles with `dashboard.wake` instead get a wake button, which sends a
# Wake-on-LAN packet to that host (one of `my.wakeOnLan.hosts`), and an
# up/down state from pinging it over mDNS. With `dashboard.poweroff` they also
# get a power-off button, which logs in to the host over SSH with a key the
# host pins to a forced command that only takes a few fixed verbs, `poweroff`
# among them (services/remote-control.nix).
# Tiles with `dashboard.reboot` stand for this host itself and get a reboot
# button, which reboots it at once; polkit lets svcctl do that and no more.
# Tiles with `dashboard.switch` get a button that starts that host's
# dotfiles-switch.service (services/dotfiles-switch.nix): directly when it's
# this host, otherwise through the same SSH login as power-off, over the
# tailnet so laptops can be switched away from home, falling back to mDNS.
# Buttons combine: one tile can wake, power off, reboot and switch.
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

  switchTiles = lib.filterAttrs (
    _: service: service.dashboard != null && service.dashboard.switch != null
  ) config.homelab.services;
  isLocal = host: host == config.my.host.name;
  # Tile name -> {hosts}: empty for this host, else its MagicDNS name, then
  # its mDNS one for when Tailscale is down on it but it's on the LAN.
  switchable = lib.mapAttrs' (
    _: service:
    let
      host = lib.toLower service.dashboard.switch;
    in
    lib.nameValuePair service.dashboard.name {
      hosts = lib.optionals (!isLocal service.dashboard.switch) [
        "${host}.${config.homelab.network.tailnetDomain}"
        "${host}.local"
      ];
    }
  ) switchTiles;
  switchFile = pkgs.writeText "svcctl-switch.json" (builtins.toJSON switchable);
  canSwitchHere = lib.any (service: isLocal service.dashboard.switch) (lib.attrValues switchTiles);

  # One `user:hash` line (`openssl passwd -6`).
  htpasswd = "svcctl/htpasswd";

  # Named for its first use; it also logs in for remote switches.
  sshKey = "svcctl/poweroff-ssh-key";
  needsKey =
    lib.any (service: service.dashboard.poweroff) (lib.attrValues wakeTiles)
    || lib.any (service: !isLocal service.dashboard.switch) (lib.attrValues switchTiles);
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
      ++ lib.optional canSwitchHere {
        assertion = config.my.services.dotfilesSwitch.enable;
        message = "a dashboard.switch tile targets this host, which needs my.services.dotfilesSwitch.enable";
      };

    users.users.svcctl = {
      isSystemUser = true;
      group = "svcctl";
    };
    users.groups.svcctl = { };

    # The target's host key must be in programs.ssh.knownHosts: svcctl runs
    # ssh with StrictHostKeyChecking and no known_hosts of its own.
    sops.secrets.${sshKey} = lib.mkIf needsKey { owner = "svcctl"; };
    sops.secrets.${htpasswd} = {
      owner = config.services.nginx.user;
      restartUnits = [ "nginx.service" ];
    };

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
    + lib.optionalString canSwitchHere ''
      polkit.addRule(function (action, subject) {
        if (
          action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.user == "svcctl" &&
          action.lookup("unit") == "dotfiles-switch.service" &&
          action.lookup("verb") == "start"
        ) {
          return polkit.Result.YES;
        }
      });
    ''
    # Same three actions as remote-control.nix grants for power-off, for the
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
            "${switchFile}"
          ]
          ++ lib.optional needsKey config.sops.secrets.${sshKey}.path
        );
        User = "svcctl";
        Group = "svcctl";
        Restart = "on-failure";
        # Talks to systemd over D-Bus (AF_UNIX), serves on loopback, and
        # broadcasts wake packets and pings (unprivileged ICMP) and SSHes to
        # power hosts off and switch them, on the LAN and the tailnet.
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

    services.nginx.virtualHosts.dashboard.locations."/api/svc/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      # The browser asks once, on the first action, and resends it after.
      extraConfig = ''
        limit_except GET {
          auth_basic "Aperture Science";
          auth_basic_user_file ${config.sops.secrets.${htpasswd}.path};
        }
      '';
    };

  };

}
