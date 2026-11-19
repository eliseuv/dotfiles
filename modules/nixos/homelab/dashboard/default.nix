# Homepage dashboard at http://<wheatley>/ linking every service on this host.
# Homepage stays on its default port behind nginx rather than binding :80
# itself - its unit drops all capabilities and runs in a private user
# namespace - and nginx is the natural place for a future reverse proxy.
#
# Tiles come from the service registry: a service gets one by setting
# `homelab.services.<name>.dashboard` next to its own config. Widgets query
# services server-side over loopback; API keys and other credentials
# (`widgetKey`, `widgetSecrets`) come from sops through an env file rendered
# at activation.
{
  config,
  inputs,
  lib,
  pkgs,
  hostSpecs,
  ...
}:
let
  # Links are written against this host and rewritten client-side (customJS)
  # to whatever name the dashboard was opened with - LAN IP, Tailscale name,
  # etc. - so one config works from anywhere without hardcoding either.
  linkHost = config.networking.hostName;
  network = config.homelab.network;
  homepagePort = config.services.homepage-dashboard.listenPort;

  groups = import ./_groups.nix;
  machineOf = import ./_machines.nix { inherit config lib hostSpecs; };
  remoteTerminals = lib.filter (machine: !machine.local && machine.terminal != null) (
    map (service: machineOf service.dashboard.host) (
      lib.attrValues (lib.filterAttrs (_: service: service.dashboard.host != null) tiled)
    )
  );

  tiled = lib.filterAttrs (_: service: service.dashboard != null) config.homelab.services;
  # Field -> sops secret for each tile's main widget; `widgetKey` is shorthand
  # for the `key` field.
  widgetSecrets =
    service:
    service.dashboard.widgetSecrets
    // lib.optionalAttrs (service.dashboard.widgetKey != null) { key = service.dashboard.widgetKey; };
  withSecrets = lib.filterAttrs (_: service: widgetSecrets service != { }) tiled;
  secretVar =
    name: field: "HOMEPAGE_VAR_${lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] "${name}_${field}")}";

  tile =
    name: service:
    let
      tileCfg = service.dashboard;
      machine = if tileCfg.host != null then machineOf tileCfg.host else null;
      address = if machine != null then machine.address else null;
      terminal = if machine != null then machine.terminal else null;
      page = if machine != null && machine.page then machine.host else null;
      local = "http://127.0.0.1:${toString service.port}";
      linked = tileCfg.link && service.port != null;
      mainWidget =
        lib.optionalAttrs (service.port != null) { url = local; }
        // tileCfg.widget
        // lib.mapAttrs (field: _: "{{${secretVar name field}}}") (widgetSecrets service);
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
    # (external ones, with an `address`): over loopback or to the internet the time
    # says nothing about the network here. It stays in the tooltip.
    // lib.optionalAttrs (tileCfg.href != null && !lib.hasPrefix "/" tileCfg.href) (
      {
        siteMonitor = tileCfg.href;
      }
      // lib.optionalAttrs (address == null) { statusStyle = "basic"; }
    )
    # A host's tile opens its terminal; controls.js keeps the click from
    # reaching a host that's down.
    // lib.optionalAttrs (tileCfg.href == null && terminal != null) {
      href = terminal;
    }
    # In place rather than a new tab: the page leads back here.
    // lib.optionalAttrs (tileCfg.href == null && terminal == null && page != null) {
      href = "/hosts/?host=${page}";
      target = "_self";
    }
    // lib.optionalAttrs (tileCfg.href == null && terminal == null && page == null && linked) {
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
        description = "systemd unit, on the tile's `host` (this one without), the entry's start/stop button controls; it must be in that host's `my.services.remoteUnits` (controls.nix).";
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
    widgetSecrets = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Further fields of `widget` taken from sops secrets, field -> secret name, for widgets that log in with more than a key.";
    };
    unit = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "systemd unit the tile's start/stop/restart buttons control (controls.nix).";
    };
    host = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Machine the tile stands for: a host in hosts/, or one in homelab.externalHosts. Its buttons, terminal, host page, uptime and where `ports` are follow from what that machine enables (_machines.nix): wake and power off, restart, switch, Tailscale on/off.";
    };
    unitHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Host (as in hosts/) `unit` lives on, controlled over SSH; it must list the unit in `my.services.remoteUnits` (controls.nix). Null for this host.";
    };
    ports = lib.mkOption {
      type = lib.types.attrsOf (lib.types.coercedTo lib.types.port (port: { inherit port; }) portEntry);
      default = { };
      description = "Label -> TCP port (or entry) on the tile's `host` (this one without) that the tile's ports menu links to while open (controls.nix); for servers with no tile of their own.";
    };
  };

  inherit (import ./_svg.nix) svgUri iris companionCube;

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

    # Declared here too so naming a secret is all a service needs; modules that
    # also use it declare it themselves, with owners and restartUnits.
    sops.secrets = lib.genAttrs (lib.concatMap (service: lib.attrValues (widgetSecrets service)) (
      lib.attrValues withSecrets
    )) (_: { });

    # Rendered root:0400; systemd reads EnvironmentFile before dropping to the
    # service's DynamicUser, so Homepage itself never needs file access.
    sops.templates."homepage-dashboard.env" = {
      content = lib.concatLines (
        lib.concatLists (
          lib.mapAttrsToList (
            name: service:
            lib.mapAttrsToList (field: secret: "${secretVar name field}=${config.sops.placeholder.${secret}}") (
              widgetSecrets service
            )
          ) withSecrets
        )
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
          greeting = {
            text = "Tailscale";
            text_size = "sm";
            href = "https://login.tailscale.com/admin/machines";
            target = "_blank";
          };
        }
        {
          resources = {
            label = "Wheatley";
            cpu = true;
            memory = true;
            disk = "/";
            expanded = true;
          };
        }
        # Must stay last: theme.css
        # themes it by position, since Homepage gives info widgets no id or
        # class hook.
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
      + builtins.readFile ./controls.js
      + builtins.readFile ./tasks.js;

      # @import must stay first, so the icon URLs are appended.
      customCSS =
        builtins.readFile ./theme.css
        + ''
          :root {
            --aperture-iris: url("${iris "black"}");
            --companion-cube: url("${companionCube}");
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
        locations = {
          "/".proxyPass = "http://127.0.0.1:${toString homepagePort}";
          # Tile icons kept here (`icon = "/icons/<file>"`), for ones neither
          # Homepage's icon sets nor its CDNs carry; Homepage loads a path as
          # is from the page's origin.
          "/icons/".alias = "${./icons}/";
        }
        # Other hosts' terminals, at the paths their tiles open, proxied so
        # they're reachable wherever the dashboard is, tailnet included; their
        # firewalls only admit this host, over the tailnet. By tailnet address
        # rather than a name: nginx resolves upstream names once at startup, and
        # fails to start if the host is asleep (.local) or tailscaled isn't up yet
        # (MagicDNS). Long read timeout so an idle terminal's websocket isn't cut
        # after nginx's default 60s. This host's own is services/ttyd.nix's.
        // lib.listToAttrs (
          map (
            machine:
            let
              address = network.tailnet.${machine.host} or null;
              port = network.ports.${machine.host}.ttyd or null;
            in
            lib.nameValuePair machine.terminal {
              proxyPass =
                if address == null || port == null then
                  throw "dashboard: ${machine.host}'s terminal (my.services.ttyd) needs homelab.network.tailnet.${machine.host} and homelab.network.ports.${machine.host}.ttyd to be proxied"
                else
                  "http://${address}:${toString port}";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_read_timeout 1d;
              '';
            }
          ) remoteTerminals
        );
      };
    };

    homelab.services.homepage = {
      port = 80;
      expose = "tailnet";
    };

  };

}
