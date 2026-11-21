# Start/stop/restart buttons on dashboard tiles whose registry entry names a
# systemd unit (`homelab.services.<name>.dashboard.unit`); with `unitHost` the
# unit is on that host, driven through the same SSH login as power-off below,
# which the host limits to its `my.services.remoteUnits`. svcctl.py serves
# the API behind the dashboard's nginx, on a Unix socket only nginx may
# connect to, so it shares the dashboard's reach (LAN + tailnet) and nothing
# else on this host gets past nginx's login. nginx puts every action (any non-GET),
# the switch logs, terminals and proxied links behind basic auth, and only
# over the tailnet, which encrypts it: the dashboard is plain HTTP, so from
# the LAN the password would cross the wire in the clear. Reading the status
# stays open everywhere, like the dashboard. svcctl runs unprivileged;
# polkit lets it manage exactly the listed units, nothing else.
# A tile with a `host` stands for that machine and gets the buttons it
# allows (_machines.nix), from its my.services for a host in hosts/, or from
# homelab.externalHosts:
# - wake, for a machine in `my.wakeOnLan.hosts` other than this one: a
#   Wake-on-LAN packet, and an up/down state from pinging it over mDNS. With
#   remotePowerOff it doubles as a power-off button, which logs in to the
#   host over SSH with a key the host pins to a forced command that only
#   takes a few fixed verbs, `poweroff` among them
#   (services/remote-control.nix).
# - restart, with remotePowerOff (or for this host): reboots it at once, this
#   one directly (polkit lets svcctl do that and no more), any other through
#   the same SSH login as power-off.
# - switch, with dotfilesSwitch: starts that host's dotfiles-switch.service
#   (services/dotfiles-switch.nix), directly when it's this host, otherwise
#   through the same SSH login, over the tailnet so laptops can be switched
#   away from home, falling back to mDNS.
# - Tailscale on/off, with remoteTailscale, for other hosts: over the same
#   SSH login (the host must be on the LAN to be reached again once it's
#   off). It shows on/off, read over SSH.
# Tiles with `dashboard.ports` get a menu linking to those ports on the
# tile's `host` (this host without one) that a TCP connect from here finds
# open; for ad-hoc dev servers, which are rarely all running.
# An entry with an `href` links to that dashboard path instead, behind the
# login; one with a `unit` gets a stop button, and a start button below the
# list while its port is closed, the unit registered like a tile's under
# "<label> · <tile>".
# Buttons combine: one tile can wake, power off, reboot, switch and toggle
# Tailscale.
# svcctl also serves every tile's controls as one list (/api/svc/tiles), the
# only description of them its clients get: the dashboard's buttons
# (controls.js), the Homelab rofi menu (wheatleymenu) and the bar
# (wheatley.sh). It holds what they show, not how svcctl reaches it: unit
# names, SSH targets and MACs stay in the rest of svcctl's config.
# svcctl also serves the host pages' read-only API (hosts.nix) under
# /api/hosts/, open like its status, over the same SSH login.
{
  config,
  lib,
  pkgs,
  hostSpecs,
  ...
}:
let
  # Created by systemd (svcctl.socket) so its group can be nginx's, which
  # svcctl isn't in; outside svcctl's RuntimeDirectory, which goes when it
  # stops.
  socketPath = "/run/svcctl.sock";
  upstream = "http://unix:${socketPath}:";

  tiles = lib.filterAttrs (_: service: service.dashboard != null) config.homelab.services;
  machineOf = import ./_machines.nix { inherit config lib hostSpecs; };
  # The machine a tile stands for (_machines.nix); null for a service tile.
  machine =
    service: if service.dashboard.host != null then machineOf service.dashboard.host else null;
  hostTiles = lib.filterAttrs (_: service: service.dashboard.host != null) tiles;
  # Tiles whose machine allows `capability`: wake, reboot, switch, ...
  tilesWith = capability: lib.filterAttrs (_: service: (machine service).${capability}) hostTiles;
  # Where a tile's ports, and its ports entries' units, are: its machine,
  # null for this host, which `portsHost` null links by whatever name the
  # client reached it with.
  portsMachine =
    service:
    let
      found = machine service;
    in
    if found != null && !found.local then found else null;
  # {hosts, user, machine} for SSHing to `found`; `hosts` empty and
  # `machine` null for this host. `machine` names its entry in `probes`.
  login =
    found:
    if found != null then
      {
        hosts = found.sshTargets;
        user = found.sshUser;
        machine = if found.local then null else found.host;
      }
    else
      {
        hosts = [ ];
        user = "remote-control";
        machine = null;
      };

  controlled = lib.filterAttrs (_: service: service.dashboard.unit != null) tiles;
  unitMachine =
    service: if service.dashboard.unitHost != null then machineOf service.dashboard.unitHost else null;
  # Tile name -> {unit, hosts, user}; the API addresses units by the name on
  # the tile, or "<label> · <tile>" for ports menu entries. `hosts` is empty
  # for units on this host.
  units =
    lib.mapAttrs' (
      _: service:
      lib.nameValuePair service.dashboard.name (
        { inherit (service.dashboard) unit; } // login (unitMachine service)
      )
    ) controlled
    // lib.listToAttrs (
      lib.concatMap (
        service:
        lib.mapAttrsToList (
          label: entry:
          lib.nameValuePair "${label} · ${service.dashboard.name}" (
            { inherit (entry) unit; } // login (portsMachine service)
          )
        ) (lib.filterAttrs (_: entry: entry.unit != null) service.dashboard.ports)
      ) (lib.attrValues tiles)
    );
  localUnits = lib.mapAttrsToList (_: target: target.unit) (
    lib.filterAttrs (_: target: target.hosts == [ ]) units
  );
  # (where, unit) for each unit on another machine, which must allow it.
  remoteUnitChecks =
    lib.mapAttrsToList (name: service: {
      where = "homelab.services.${name}.dashboard.unitHost";
      found = unitMachine service;
      inherit (service.dashboard) unit;
    }) (lib.filterAttrs (_: service: unitMachine service != null) controlled)
    ++ lib.concatLists (
      lib.mapAttrsToList (
        name: service:
        lib.mapAttrsToList (label: entry: {
          where = "homelab.services.${name}.dashboard.ports.${label}.unit";
          found = portsMachine service;
          inherit (entry) unit;
        }) (lib.filterAttrs (_: entry: entry.unit != null) service.dashboard.ports)
      ) (lib.filterAttrs (_: service: portsMachine service != null) tiles)
    );

  # Tile name -> {mac, host, user, poweroff, machine}.
  wakeable = lib.mapAttrs' (
    _: service:
    let
      found = machine service;
    in
    lib.nameValuePair service.dashboard.name {
      inherit (found) mac poweroff;
      host = found.pingHost;
      user = found.sshUser;
      machine = found.host;
    }
  ) (tilesWith "wake");

  # Tile name -> {hosts, user} for tiles whose machine allows `capability`.
  hostActions =
    capability:
    lib.mapAttrs' (_: service: lib.nameValuePair service.dashboard.name (login (machine service))) (
      tilesWith capability
    );
  actsHere =
    capability: lib.any (service: (machine service).local) (lib.attrValues (tilesWith capability));
  canRebootHere = actsHere "reboot";
  canSwitchHere = actsHere "switch";

  # Tile name -> {hosts, ports, machine}; `hosts` empty for this host.
  portTargets = lib.mapAttrs' (
    _: service:
    lib.nameValuePair service.dashboard.name {
      inherit (login (portsMachine service)) hosts machine;
      ports = map (entry: entry.port) (lib.attrValues service.dashboard.ports);
    }
  ) (lib.filterAttrs (_: service: service.dashboard.ports != { }) tiles);

  # Machine -> {hosts, lan, mac}: what svcctl pings to tell whether another
  # machine is up, once however many tiles act on it. With `lan` (a machine
  # it can wake) that LAN name is tried first, and whether it answers is
  # kept apart, for the wake button; `mac` also tells it booted into
  # Windows. Then `hosts` in turn, its SSH names.
  probes = lib.listToAttrs (
    map
      (found: {
        name = found.host;
        value = {
          hosts = found.sshTargets;
          lan = if found.wake then found.pingHost else null;
          mac = if found.wake then found.mac else null;
        };
      })
      (
        lib.filter (found: found != null && !found.local) (
          map machine (lib.attrValues hostTiles)
          ++ map unitMachine (lib.attrValues controlled)
          ++ map portsMachine (lib.attrValues tiles)
        )
      )
  );

  groupIndex =
    group: lib.lists.findFirstIndex (entry: entry.name == group) null (import ./_groups.nix);
  dashboardOrder = lib.sort (
    a: b:
    let
      keyA = tiles.${a}.dashboard;
      keyB = tiles.${b}.dashboard;
    in
    if keyA.group != keyB.group then
      groupIndex keyA.group < groupIndex keyB.group
    else if keyA.order != keyB.order then
      keyA.order < keyB.order
    else
      a < b
  ) (lib.attrNames tiles);
  # Served at /api/svc/tiles. `controls` are the buttons; the switch button
  # moves to the host page when the tile has one. `uptime` names the host
  # whose uptime the tile shows (hosts.nix): a page's host, or an SNMP
  # machine. A ports entry's `unit` is the name svcctl knows it by in
  # `units`, null without one. The rofi menu leaves out the tile of the
  # machine it runs on, and SSHes to `address` when set.
  tileList = map (
    name:
    let
      tile = tiles.${name}.dashboard;
      found = machine tiles.${name};
      can = capability: found != null && found.${capability};
      ports = portsMachine tiles.${name};
    in
    {
      inherit (tile) name host;
      here = found != null && found.local;
      address = if found != null then found.address else null;
      page = if can "page" then tile.host else null;
      portsHost = if tile.ports != { } && ports != null then ports.host else null;
      terminal = if found != null then found.terminal else null;
      uptime = if can "page" || (found != null && found.snmp != null) then tile.host else null;
      controls =
        lib.optional (tile.unit != null) "unit"
        ++ lib.filter can [
          "wake"
          "poweroff"
          "reboot"
          "switch"
          "tailscale"
        ]
        ++ lib.optional (tile.ports != { }) "ports";
      ports = lib.sort (a: b: a.port < b.port) (
        lib.mapAttrsToList (label: entry: {
          inherit label;
          inherit (entry) port href;
          unit = if entry.unit != null then "${label} · ${tile.name}" else null;
        }) tile.ports
      );
    }
  ) dashboardOrder;

  configFile = pkgs.writeText "svcctl.json" (
    builtins.toJSON (
      {
        inherit units;
        wake = wakeable;
        reboot = hostActions "reboot";
        switch = hostActions "switch";
        tailscale = hostActions "tailscale";
        ports = portTargets;
        inherit probes;
        tiles = tileList;
        # For links to other hosts' ports by the name the client reached this
        # one with (controls.js).
        tailnet = {
          domain = config.homelab.network.tailnetDomain;
          address = config.homelab.network.tailnetAddress;
        };
      }
      // lib.optionalAttrs (config.homelab.svcctl.hostPages != null) {
        pages = config.homelab.svcctl.hostPages;
      }
    )
  );

  # svcctl.py imports host_pages.py from its own directory.
  source = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./svcctl.py
      ./host_pages.py
    ];
  };

  # Dashboard paths of tile terminals and links (e.g. a proxied Pluto), which
  # get the actions' login.
  loginPaths = lib.filter (path: path != null && lib.hasPrefix "/" path) (
    lib.concatMap (
      service:
      [
        (if machine service != null then (machine service).terminal else null)
        service.dashboard.href
      ]
      ++ map (entry: entry.href) (lib.attrValues service.dashboard.ports)
    ) (lib.attrValues tiles)
  );
  # One realm everywhere, so the browser reuses one login.
  realm = "Aperture Science";
  passwords = "auth_basic_user_file ${config.sops.secrets.${htpasswd}.path};";
  basicAuth = ''
    auth_basic "${realm}";
    ${passwords}
  '';
  # From the LAN, what needs the login is refused before nginx asks for it:
  # a 401 there would have the browser send the password in the clear.
  # `return` runs in the rewrite phase, ahead of auth_basic's access phase.
  # $dashboard_tailnet is the http block's geo below.
  lanRefusal = "only over Tailscale: open the dashboard by its tailnet name";
  tailnetOnly = ''
    if ($dashboard_tailnet = 0) {
      return 403 "This needs the dashboard login, served ${lanRefusal}.";
    }
  '';
  # The same for the API, as the {error} its clients show.
  tailnetOnlyApi = ''
    default_type application/json;
    if ($dashboard_tailnet = 0) {
      return 403 '{"error": "controls answer ${lanRefusal}"}';
    }
  '';

  # One `user:hash` line (`openssl passwd -6`).
  htpasswd = "svcctl/htpasswd";

  # Named for its first use; it also logs in for remote switches and to read
  # other hosts' pages.
  sshKey = "svcctl/poweroff-ssh-key";
  needsKey =
    lib.any (
      service:
      let
        found = machine service;
      in
      !found.local && (found.poweroff || found.reboot || found.switch || found.tailscale || found.page)
    ) (lib.attrValues hostTiles)
    || lib.any (target: target.hosts != [ ]) (lib.attrValues units);
in
{

  options.homelab.svcctl.hostPages = lib.mkOption {
    type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
    default = null;
    internal = true;
    description = "The host pages' section of svcctl's config, set by hosts.nix; null for no host pages.";
  };

  config = lib.mkIf config.my.homelab.enable {

    assertions =
      lib.mapAttrsToList (name: service: {
        assertion = service.dashboard.unit != null;
        message = "homelab.services.${name}.dashboard.unitHost needs dashboard.unit";
      }) (lib.filterAttrs (_: service: service.dashboard.unitHost != null) tiles)
      ++ map (check: {
        assertion = lib.elem check.unit check.found.remoteUnits;
        message = "${check.where}: ${check.unit} is not in ${check.found.host}'s my.services.remoteUnits, so its forced command would refuse it";
      }) remoteUnitChecks;

    users.users.svcctl = {
      isSystemUser = true;
      group = "svcctl";
      extraGroups = lib.optional canSwitchHere "systemd-journal";
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
          var units = ${builtins.toJSON localUnits};
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
          ["dotfiles-switch.service", "dotfiles-home-switch.service"].indexOf(action.lookup("unit")) >= 0 &&
          action.lookup("verb") == "start"
        ) {
          return polkit.Result.YES;
        }
      });
    ''
    # Same three actions as remote-control.nix grants for power-off, for the
    # same reasons: someone is usually logged in, and sessions hold inhibitors.
    + lib.optionalString canRebootHere ''
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

    systemd.sockets.svcctl = {
      description = "Dashboard service controls' API";
      wantedBy = [ "sockets.target" ];
      listenStreams = [ socketPath ];
      socketConfig = {
        SocketUser = "svcctl";
        SocketGroup = config.services.nginx.group;
        SocketMode = "0660";
      };
    };

    systemd.services.svcctl = {
      description = "Dashboard service controls";
      # Started at boot rather than on the first request: its pollers keep
      # the state that request reads.
      wantedBy = [ "multi-user.target" ];
      requires = [ "svcctl.socket" ];
      after = [ "svcctl.socket" ];
      path = [
        config.systemd.package
        pkgs.iputils
        pkgs.openssh
      ];
      # For this host's own switch tile; remote ones run it over SSH.
      environment.SVCCTL_SWITCH_STATUS = lib.getExe (
        import ../../services/_switch-status.nix {
          inherit pkgs;
          systemd = config.systemd.package;
        }
      );
      serviceConfig = {
        ExecStart = lib.concatStringsSep " " (
          [
            (lib.getExe pkgs.python3)
            "${source}/svcctl.py"
            "socket"
            "${configFile}"
          ]
          ++ lib.optional needsKey config.sops.secrets.${sshKey}.path
        );
        User = "svcctl";
        Group = "svcctl";
        # The shared SSH connections' sockets (svcctl.py), and net-snmp's
        # state for the host pages.
        RuntimeDirectory = "svcctl";
        Restart = "on-failure";
        # Talks to systemd over D-Bus and serves nginx (AF_UNIX), and
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

    # The tailnet's addresses (Tailscale's CGNAT and ULA ranges) and this
    # host. $dashboard_lan_action is a write from anywhere else: reads stay
    # open on the LAN. $dashboard_action_realm asks for the login on writes
    # only; as a variable rather than limit_except, which hands non-GET
    # requests to a nested location before the rewrite phase, so the LAN
    # refusal in /api/svc/ would never run for them.
    services.nginx.appendHttpConfig = ''
      geo $dashboard_tailnet {
        default 0;
        127.0.0.0/8 1;
        ::1 1;
        100.64.0.0/10 1;
        fd7a:115c:a1e0::/48 1;
      }
      map "$dashboard_tailnet:$request_method" $dashboard_lan_action {
        default 1;
        ~^1: 0;
        0:GET 0;
        0:HEAD 0;
      }
      map $request_method $dashboard_action_realm {
        default "${realm}";
        GET off;
        HEAD off;
      }
    '';

    services.nginx.virtualHosts.dashboard.locations = {
      "/api/svc/" = {
        proxyPass = upstream;
        extraConfig = ''
          default_type application/json;
          if ($dashboard_lan_action) {
            return 403 '{"error": "controls answer ${lanRefusal}"}';
          }
          auth_basic $dashboard_action_realm;
          ${passwords}
        '';
      };
      # Build and activation output, which says more about a host than the
      # status does: behind the login, like the actions.
      "/api/svc/switch-log/" = {
        proxyPass = upstream;
        extraConfig = tailnetOnlyApi + basicAuth;
      };
      # The host pages' API (host_pages.py); open, read-only.
      "/api/hosts/".proxyPass = upstream;
      # Not every browser asks for a login when a script's request gets a
      # 401 (Firefox for Android doesn't), but every one does for a page, so
      # controls.js sends the user here on a 401. Logged in at this path,
      # the browser also sends the login with every later /api/svc/ request
      # on its own, rather than only to paths it has already seen.
      # `return` would run before auth_basic, skipping the login; try_files
      # runs after it, finds nothing and hands over to the redirect.
      "= /api/svc/login" = {
        extraConfig = ''
          ${tailnetOnly}
          ${basicAuth}
          try_files /nonexistent @svcctl-logged-in;
        '';
      };
      "@svcctl-logged-in".return = "302 /";
    }
    # Merged into the locations hosts declare for their terminals and
    # proxied links, which bring their own proxyPass. Same realm, so the
    # browser reuses one login.
    // lib.genAttrs loginPaths (_: {
      extraConfig = ''
        default_type text/plain;
        ${tailnetOnly}
        ${basicAuth}
      '';
    });

  };

}
