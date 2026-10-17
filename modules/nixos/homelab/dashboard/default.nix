# Homepage dashboard at http://<wheatley>/ linking every service on this host.
# Homepage stays on its default port behind nginx rather than binding :80
# itself - its unit drops all capabilities and runs in a private user
# namespace - and nginx is the natural place for a future reverse proxy.
#
# Tiles come from the service registry: a service gets one by setting
# `homelab.services.<name>.dashboard` next to its own config. Widgets query
# services server-side over loopback; API keys (`widgetKey`) come from sops
# through an env file rendered at activation.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Links are written against this host and rewritten client-side (customJS)
  # to whatever name the dashboard was opened with - LAN IP, Tailscale name,
  # etc. - so one config works from anywhere without hardcoding either.
  linkHost = config.networking.hostName;
  network = config.homelab.network;
  homepagePort = config.services.homepage-dashboard.listenPort;

  # Tile groups, in display order, on one four-column grid: theme.css evens
  # out the rows and sets the first two side by side, as halves whose two
  # columns land on the four below.
  groups = [
    {
      name = "Headless servers";
      columns = 2;
    }
    {
      name = "Desktops";
      columns = 2;
    }
    {
      name = "Tools";
      columns = 4;
    }
    {
      name = "Media";
      columns = 4;
    }
    {
      name = "Games";
      columns = 4;
    }
  ];

  tiled = lib.filterAttrs (_: service: service.dashboard != null) config.homelab.services;
  withKey = lib.filterAttrs (_: service: service.dashboard.widgetKey != null) tiled;
  controlledTiles = lib.mapAttrsToList (_: service: service.dashboard.name) (
    lib.filterAttrs (_: service: service.dashboard.unit != null) tiled
  );
  wakeTiles = lib.mapAttrsToList (_: service: service.dashboard.name) (
    lib.filterAttrs (_: service: service.dashboard.wake != null) tiled
  );
  poweroffTiles = lib.mapAttrsToList (_: service: service.dashboard.name) (
    lib.filterAttrs (_: service: service.dashboard.poweroff) tiled
  );
  # Tile name -> terminal URL.
  terminalTiles = lib.mapAttrs' (
    _: service: lib.nameValuePair service.dashboard.name service.dashboard.terminal
  ) (lib.filterAttrs (_: service: service.dashboard.terminal != null) tiled);
  # Tile name -> whether it reboots this host, the one serving the page.
  rebootTiles = lib.mapAttrs' (
    _: service:
    lib.nameValuePair service.dashboard.name (service.dashboard.reboot == config.my.host.name)
  ) (lib.filterAttrs (_: service: service.dashboard.reboot != null) tiled);
  # Tiles with a host page switch from there (its config page button) rather
  # than from a button of their own.
  switchTiles = lib.mapAttrsToList (_: service: service.dashboard.name) (
    lib.filterAttrs (
      _: service: service.dashboard.switch != null && service.dashboard.page == null
    ) tiled
  );
  # Tile name -> host whose page the tile's config page button opens.
  pageTiles = lib.mapAttrs' (
    _: service: lib.nameValuePair service.dashboard.name service.dashboard.page
  ) (lib.filterAttrs (_: service: service.dashboard.page != null) tiled);
  # Tile name -> hostctl's name for the host, whose uptime the tile shows
  # (hosts.nix): a page's host, or the `wake` host of an `snmp` tile.
  uptimeTiles =
    pageTiles
    // lib.mapAttrs' (_: service: lib.nameValuePair service.dashboard.name service.dashboard.wake) (
      lib.filterAttrs (_: service: service.dashboard.snmp != null) tiled
    );
  tailscaleTiles = lib.mapAttrsToList (_: service: service.dashboard.name) (
    lib.filterAttrs (_: service: service.dashboard.tailscale != null) tiled
  );
  # Tile name -> {host, ports: [{name, port, href, unit}]}, by port; `host`
  # null for this one, `unit` the name svcctl knows the entry's unit by
  # (controls.nix).
  portTiles = lib.mapAttrs' (
    _: service:
    lib.nameValuePair service.dashboard.name {
      host = service.dashboard.portsHost;
      ports = lib.sort (a: b: a.port < b.port) (
        lib.mapAttrsToList (name: entry: {
          inherit name;
          inherit (entry) port href;
          unit = if entry.unit != null then "${name} · ${service.dashboard.name}" else null;
        }) service.dashboard.ports
      );
    }
  ) (lib.filterAttrs (_: service: service.dashboard.ports != { }) tiled);
  keyVar = name: "HOMEPAGE_VAR_${lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] name)}_KEY";

  tile =
    name: service:
    let
      tileCfg = service.dashboard;
      local = "http://127.0.0.1:${toString service.port}";
      linked = tileCfg.link && service.port != null;
      mainWidget =
        lib.optionalAttrs (service.port != null) { url = local; }
        // tileCfg.widget
        // lib.optionalAttrs (tileCfg.widgetKey != null) { key = "{{${keyVar name}}}"; };
    in
    {
      inherit (tileCfg) icon;
    }
    // lib.optionalAttrs (tileCfg.description != null) {
      inherit (tileCfg) description;
    }
    // lib.optionalAttrs (tileCfg.href != null) {
      inherit (tileCfg) href;
    }
    # Homepage monitors server-side, where a path on this dashboard means
    # nothing. Up/down rather than a response time, except for LAN machines
    # (those with an `address`): over loopback or to the internet the time
    # says nothing about the network here. It stays in the tooltip.
    // lib.optionalAttrs (tileCfg.href != null && !lib.hasPrefix "/" tileCfg.href) (
      {
        siteMonitor = tileCfg.href;
      }
      // lib.optionalAttrs (tileCfg.address == null) { statusStyle = "basic"; }
    )
    # A host's tile opens its terminal; controls.js keeps the click from
    # reaching a host that's down.
    // lib.optionalAttrs (tileCfg.href == null && tileCfg.terminal != null) {
      href = tileCfg.terminal;
    }
    # In place rather than a new tab: the page leads back here.
    // lib.optionalAttrs (tileCfg.href == null && tileCfg.terminal == null && tileCfg.page != null) {
      href = "/hosts/?host=${tileCfg.page}";
      target = "_self";
    }
    //
      lib.optionalAttrs
        (tileCfg.href == null && tileCfg.terminal == null && tileCfg.page == null && linked)
        {
          href = "http://${linkHost}:${toString service.port}";
          siteMonitor = local;
          statusStyle = "basic";
        }
    // lib.optionalAttrs (tileCfg.widget != null && tileCfg.extraWidgets == [ ]) {
      widget = mainWidget;
    }
    # One list rather than `widget` beside `widgets`: Homepage appends a
    # `widget` after the list, which would put the main one last.
    // lib.optionalAttrs (tileCfg.extraWidgets != [ ]) {
      widgets = lib.optional (tileCfg.widget != null) mainWidget ++ tileCfg.extraWidgets;
    };

  groupTiles =
    group:
    map (name: { ${tiled.${name}.dashboard.name} = tile name tiled.${name}; }) (
      lib.sort (
        a: b:
        let
          orderA = tiled.${a}.dashboard.order;
          orderB = tiled.${b}.dashboard.order;
        in
        if orderA != orderB then orderA < orderB else a < b
      ) (lib.attrNames (lib.filterAttrs (_: service: service.dashboard.group == group) tiled))
    );

  portEntry = lib.types.submodule {
    options = {
      port = lib.mkOption {
        type = lib.types.port;
        description = "Port probed for open/closed, and linked to unless `href` is set.";
      };
      href = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path on this dashboard to link to instead, for servers it proxies; it gets the actions' login (controls.nix).";
      };
      unit = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "systemd unit, on the tile's `portsHost`, the entry's start/stop button controls; as `unit`/`unitHost` for tiles (controls.nix).";
      };
    };
  };

  tileOptions = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "Tile title.";
    };
    group = lib.mkOption {
      type = lib.types.str;
      description = "Tile group; one of the groups listed in the dashboard module.";
    };
    order = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = "Position within the group, lowest first; ties sort by service name.";
    };
    description = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    icon = lib.mkOption { type = lib.types.str; };
    link = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Link to (and monitor) the service's port. Off for services without a web UI.";
    };
    href = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Explicit link and monitor URL, for things not on this host; a path (served by this dashboard's nginx) gets its login and no monitor.";
    };
    widget = lib.mkOption {
      type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
      default = null;
      description = "Homepage widget; `url` defaults to the service's port on loopback.";
    };
    extraWidgets = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
      description = "Further Homepage widgets, each a row below `widget`; taken as given, so each needs its own full `url`.";
    };
    widgetKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "sops secret holding the widget's API key.";
    };
    unit = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "systemd unit the tile's start/stop/restart buttons control (controls.nix).";
    };
    unitHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Host (as in hosts/) `unit` lives on, controlled over SSH; it must list the unit in `my.services.remoteUnits` (controls.nix). Null for this host.";
    };
    wake = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Host in `my.wakeOnLan.hosts` the tile's wake button wakes and shows up/down (controls.nix).";
    };
    poweroff = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Let a `wake` tile's on/off button also power the host off; the host needs `my.services.remotePowerOff` (controls.nix).";
    };
    terminal = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Web terminal URL the tile itself opens, live while the host is up (controls.js); a path is served by this dashboard's nginx, behind its login.";
    };
    reboot = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Host (as in hosts/) the tile's restart button reboots: this one directly, any other over SSH, which needs `my.services.remotePowerOff` there (controls.nix).";
    };
    switch = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Host (as in hosts/) whose dotfiles-switch.service the tile's switch button starts (controls.nix).";
    };
    page = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Host (as in hosts/) whose page - generations, diffs, deploy status against master - the tile's config page button opens, in place of its switch button (hosts.nix); it needs my.services.dotfilesSwitch.";
    };
    snmp = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "sops secret holding a net-snmp client config (SNMPv3 credentials) with which hostctl reads the `wake` host's uptime, for machines that can't run host-report; needs `address` (hosts.nix).";
    };
    address = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Address svcctl pings and SSHes to for this host's buttons, instead of the `<host>.local` and tailnet names derived from the host name; for machines outside hosts/ (controls.nix).";
    };
    sshUser = lib.mkOption {
      type = lib.types.str;
      default = "remote-control";
      description = "User svcctl logs in as for this host's buttons; the default is the forced-command user of services/remote-control.nix (controls.nix).";
    };
    ports = lib.mkOption {
      type = lib.types.attrsOf (lib.types.coercedTo lib.types.port (port: { inherit port; }) portEntry);
      default = { };
      description = "Label -> TCP port (or entry) the tile's ports menu links to, each shown open or closed (controls.nix); for servers with no tile of their own.";
    };
    portsHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Host (as in hosts/) `ports` are on, reached over the tailnet or mDNS as the dashboard was; null for this host.";
    };
    tailscale = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Host (as in hosts/) whose Tailscale the tile's tailscale button turns on and off, over SSH; the host needs `my.services.remoteTailscale` (controls.nix).";
    };
  };

  inherit (import ./_svg.nix) svgUri iris;

  hostIcons = import ./_host-icons.nix;

in
{

  options.homelab.services = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.dashboard = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule { options = tileOptions; });
          default = null;
          description = "Dashboard tile for this service; null for none.";
        };
      }
    );
  };

  config = lib.mkIf config.my.homelab.enable {

    assertions = lib.mapAttrsToList (name: service: {
      assertion = lib.any (group: group.name == service.dashboard.group) groups;
      message = "homelab.services.${name}.dashboard.group: unknown group ${service.dashboard.group}";
    }) tiled;

    # Declared here too so a widgetKey is all a service needs; modules that also
    # use the key declare it themselves, with owners and restartUnits.
    sops.secrets = lib.mapAttrs' (
      _: service: lib.nameValuePair service.dashboard.widgetKey { }
    ) withKey;

    # Rendered root:0400; systemd reads EnvironmentFile before dropping to the
    # service's DynamicUser, so Homepage itself never needs file access.
    sops.templates."homepage-dashboard.env" = {
      content = lib.concatLines (
        lib.mapAttrsToList (
          name: service: "${keyVar name}=${config.sops.placeholder.${service.dashboard.widgetKey}}"
        ) withKey
      );
      restartUnits = [ "homepage-dashboard.service" ];
    };

    # Homepage caches its config in process, and a switch only relinks
    # /etc/homepage-dashboard, so it would keep serving the old layout.
    systemd.services.homepage-dashboard.restartTriggers = lib.mapAttrsToList (_: entry: entry.source) (
      lib.filterAttrs (name: _: lib.hasPrefix "homepage-dashboard/" name) config.environment.etc
    );

    services.homepage-dashboard = {
      enable = true;
      # nixos-26.05 ships 1.x, whose qBittorrent widget can only log in with a
      # username/password; API key (Bearer) support arrived in 2.x.
      package =
        (import inputs.nixpkgs {
          system = pkgs.stdenv.hostPlatform.system;
        }).homepage-dashboard;
      environmentFiles = [ config.sops.templates."homepage-dashboard.env".path ];

      # Host header check (DNS-rebinding guard). nginx forwards the browser's
      # Host, which on :80 carries no port.
      allowedHosts = builtins.concatStringsSep "," [
        linkHost
        "${linkHost}.local"
        "${linkHost}.${network.tailnetDomain}"
        network.tailnetAddress
      ];

      settings = {
        title = "Aperture Science · Wheatley";
        favicon = iris "#ff9a00";
        # Pinned so theme.css can override this palette's variables.
        # theme is left unset: theme.js drives the hidden toggle.
        color = "zinc";
        headerStyle = "clean";
        # A list, not an attrset: Homepage orders groups by layout keys, and
        # an attrset would serialize them alphabetically.
        layout = map (group: {
          ${group.name} = {
            style = "row";
            inherit (group) columns;
          };
        }) groups;
      };

      widgets = [
        {
          greeting = {
            text = "Aperture Science Enrichment Center";
            text_size = "xl";
          };
        }
        {
          resources = {
            label = "Wheatley";
            cpu = true;
            memory = true;
            disk = "/";
            expanded = true;
            uptime = true;
          };
        }
        {
          greeting = {
            text = "Tailscale";
            text_size = "sm";
            href = "https://login.tailscale.com/admin/machines";
            target = "_blank";
          };
        }
        # Must stay the last widget: theme.css themes it by position,
        # since Homepage gives info widgets no id or class hook.
        {
          resources = {
            label = "Companion Cube";
            disk = "/mnt/media";
            expanded = true;
          };
        }
      ];

      services = map (group: { ${group.name} = groupTiles group.name; }) (
        lib.filter (group: groupTiles group.name != [ ]) groups
      );

      customJS = ''
        const linkHost = ${builtins.toJSON linkHost};
        const retarget = () => {
          if (location.hostname === linkHost) return;
          for (const a of document.querySelectorAll("a[href]")) {
            if (a.hostname === linkHost) a.hostname = location.hostname;
          }
        };
        // Homepage renders client-side, so links appear after this runs.
        new MutationObserver(retarget).observe(document.documentElement, {
          childList: true,
          subtree: true,
        });
        retarget();
      ''
      + builtins.readFile ./theme.js
      + ''
        const svcctlTiles = ${builtins.toJSON controlledTiles};
        const svcctlWakeTiles = ${builtins.toJSON wakeTiles};
        const svcctlPoweroffTiles = ${builtins.toJSON poweroffTiles};
        const svcctlTerminals = ${builtins.toJSON terminalTiles};
        const svcctlRebootTiles = ${builtins.toJSON rebootTiles};
        const svcctlSwitchTiles = ${builtins.toJSON switchTiles};
        const svcctlPages = ${builtins.toJSON pageTiles};
        const svcctlUptimes = ${builtins.toJSON uptimeTiles};
        const svcctlTailscaleTiles = ${builtins.toJSON tailscaleTiles};
        const svcctlPorts = ${builtins.toJSON portTiles};
        const svcctlTailnet = ${
          builtins.toJSON {
            domain = network.tailnetDomain;
            address = network.tailnetAddress;
          }
        };
      ''
      + builtins.readFile ./controls.js
      + builtins.readFile ./tasks.js;

      # @import must stay first, so the icon URLs are appended.
      customCSS =
        builtins.readFile ./theme.css
        + ''
          :root {
            --aperture-iris: url("${iris "black"}");
            --companion-cube: url("${hostIcons.cube.on}");
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (
                name: states:
                lib.concatStringsSep "\n" (
                  lib.mapAttrsToList (state: uri: "--host-${name}-${state}: url(\"${uri}\");") states
                )
              ) hostIcons
            )}
          }
        ''
        + builtins.readFile ./controls.css
        + builtins.readFile ./tasks.css;
    };

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts.dashboard = {
        default = true;
        locations."/".proxyPass = "http://127.0.0.1:${toString homepagePort}";
        # Tile icons kept here (`icon = "/icons/<file>"`), for ones neither
        # Homepage's icon sets nor its CDNs carry; Homepage loads a path as is
        # from the page's origin.
        locations."/icons/".alias = "${./icons}/";
      };
    };
    homelab.services.homepage = {
      port = 80;
      expose = "tailnet";
    };

  };

}
