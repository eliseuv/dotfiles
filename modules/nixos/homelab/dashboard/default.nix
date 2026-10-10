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

  # Tile groups, in display order.
  groups = [
    {
      name = "Hosts";
      columns = 3;
    }
    {
      name = "Tools";
      columns = 3;
    }
    {
      name = "Media";
      columns = 3;
    }
    { name = "Dev"; }
    { name = "Games"; }
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
  switchTiles = lib.mapAttrsToList (_: service: service.dashboard.name) (
    lib.filterAttrs (_: service: service.dashboard.switch != null) tiled
  );
  tailscaleTiles = lib.mapAttrsToList (_: service: service.dashboard.name) (
    lib.filterAttrs (_: service: service.dashboard.tailscale != null) tiled
  );
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
    // lib.optionalAttrs (tileCfg.href == null && linked) {
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
      description = "Web terminal URL for the tile's terminal button, live while the host is up (controls.js); a path is served by this dashboard's nginx, behind its login.";
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
    tailscale = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Host (as in hosts/) whose Tailscale the tile's tailscale button turns on and off, over SSH; the host needs `my.services.remoteTailscale` (controls.nix).";
    };
  };

  # Percent-encoded so it works as a data URI in both favicons and CSS url().
  svgUri =
    svg:
    "data:image/svg+xml," + builtins.replaceStrings [ "<" ">" "#" " " ] [ "%3C" "%3E" "%23" "%20" ] svg;

  # Generic 8-blade camera iris, used as the favicon and (as a CSS mask) the
  # header mark.
  iris =
    fill:
    svgUri "<svg xmlns='http://www.w3.org/2000/svg' viewBox='-50 -50 100 100'><mask id='m'><circle r='46' fill='white'/><polygon points='15,0 10.6,10.6 0,15 -10.6,10.6 -15,0 -10.6,-10.6 0,-15 10.6,-10.6'/><path stroke='black' stroke-width='4' d='M15 0L24.4 45.9M10.6 10.6L-15.2 49.7M0 15L-45.9 24.4M-10.6 10.6L-49.7 -15.2M-15 0L-24.4 -45.9M-10.6 -10.6L15.2 -49.7M0 -15L45.9 -24.4M10.6 -10.6L49.7 15.2'/></mask><circle r='46' fill='${fill}' mask='url(#m)'/></svg>";

  # Companion Cube face (corner pads, ring, heart) as a CSS mask for the NAS
  # storage readout and service tile.
  companionCube = svgUri "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><rect x='2' y='2' width='20' height='20' rx='3' fill='none' stroke='black' stroke-width='1.8'/><rect x='2' y='2' width='6' height='6' rx='2'/><rect x='16' y='2' width='6' height='6' rx='2'/><rect x='2' y='16' width='6' height='6' rx='2'/><rect x='16' y='16' width='6' height='6' rx='2'/><circle cx='12' cy='12' r='5' fill='none' stroke='black' stroke-width='1.6'/><path d='M12 14.6l-2.3-2.2a1.35 1.35 0 0 1 2.3-1.8a1.35 1.35 0 0 1 2.3 1.8z'/></svg>";

  # GLaDOS from the front, after the usual fan art: her stalk and cables, the
  # tall head and the disc behind it, kept apart by a gap cut around the head,
  # as a CSS mask for her wake tile. The faceplate is drawn separately, as a
  # dark layer under the optic (theme.css), since a mask has one colour; its
  # light rim keeps it apart from the dark chassis of the light theme.
  glados =
    let
      head = "M9.4 9C9.4 6 11 5.2 16 4.8C21 5.2 22.6 6 22.6 9C22 13 22 19 22.6 23C22.6 26.5 19.5 28.4 16 28.4C12.5 28.4 9.4 26.5 9.4 23C10 19 10 13 9.4 9z";
    in
    svgUri "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'><mask id='m'><rect width='32' height='32' fill='white'/><path d='${head}' fill='black' stroke='black' stroke-width='1.8'/></mask><g mask='url(#m)'><circle cx='16' cy='16' r='9.6'/><path d='M14 0C14 2 11.6 3 11.2 6.4M18 0C18 2 20.4 3 20.8 6.4' fill='none' stroke='black' stroke-width='1.1'/></g><rect x='14.4' y='0' width='3.2' height='6'/><path d='${head}'/></svg>";
  gladosFace = svgUri "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'><rect x='12.6' y='10.4' width='6.8' height='13.5' rx='2.5' fill='#141414' stroke='#b4b4b4' stroke-width='0.7'/></svg>";

  # Wheatley's personality core: the sphere between its two carry handles, as
  # a CSS mask for his reboot tile; theme.css draws the optic into it.
  wheatley = svgUri "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'><circle cx='16' cy='17' r='11'/><path fill='none' stroke='black' stroke-width='2.5' stroke-linecap='round' d='M5 9A13 13 0 0 1 27 9M5 25A13 13 0 0 0 27 25'/></svg>";
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
          ${group.name} = lib.optionalAttrs (group ? columns) {
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
        const svcctlTailscaleTiles = ${builtins.toJSON tailscaleTiles};
      ''
      + builtins.readFile ./controls.js
      + builtins.readFile ./tasks.js;

      # @import must stay first in the stylesheet, so the mask is appended.
      customCSS =
        builtins.readFile ./theme.css
        + ''
          :root {
            --aperture-iris: url("${iris "black"}");
            --companion-cube: url("${companionCube}");
            --glados: url("${glados}");
            --glados-face: url("${gladosFace}");
            --wheatley: url("${wheatley}");
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
