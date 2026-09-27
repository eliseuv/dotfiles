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
      name = "Media";
      columns = 3;
    }
    {
      name = "Management";
      columns = 4;
    }
    {
      name = "Tools";
      columns = 3;
    }
    { name = "Dev"; }
  ];

  tiled = lib.filterAttrs (_: service: service.dashboard != null) config.homelab.services;
  withKey = lib.filterAttrs (_: service: service.dashboard.widgetKey != null) tiled;
  keyVar = name: "HOMEPAGE_VAR_${lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] name)}_KEY";

  tile =
    name: service:
    let
      tileCfg = service.dashboard;
      local = "http://127.0.0.1:${toString service.port}";
      linked = tileCfg.link && service.port != null;
    in
    {
      inherit (tileCfg) description icon;
    }
    // lib.optionalAttrs (tileCfg.href != null) {
      inherit (tileCfg) href;
      siteMonitor = tileCfg.href;
    }
    // lib.optionalAttrs (tileCfg.href == null && linked) {
      href = "http://${linkHost}:${toString service.port}";
      siteMonitor = local;
    }
    // lib.optionalAttrs (tileCfg.widget != null) {
      widget =
        lib.optionalAttrs (service.port != null) { url = local; }
        // tileCfg.widget
        // lib.optionalAttrs (tileCfg.widgetKey != null) { key = "{{${keyVar name}}}"; };
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
    description = lib.mkOption { type = lib.types.str; };
    icon = lib.mkOption { type = lib.types.str; };
    link = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Link to (and monitor) the service's port. Off for services without a web UI.";
    };
    href = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Explicit link and monitor URL, for things not on this host.";
    };
    widget = lib.mkOption {
      type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
      default = null;
      description = "Homepage widget; `url` defaults to the service's port on loopback.";
    };
    widgetKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "sops secret holding the widget's API key.";
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

  config = {

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
        network.lanAddress
        network.tailnetAddress
      ];

      settings = {
        title = "Aperture Science · Wheatley";
        favicon = iris "#ff9a00";
        # Pinned so theme.css can override this palette's variables.
        # theme is left unset: theme.js drives the hidden toggle.
        color = "zinc";
        headerStyle = "clean";
        layout = lib.listToAttrs (
          map (
            group:
            lib.nameValuePair group.name {
              style = "row";
              inherit (group) columns;
            }
          ) (lib.filter (group: group ? columns) groups)
        );
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
            label = "System";
            cpu = true;
            memory = true;
            uptime = true;
          };
        }
        {
          resources = {
            label = "Wheatley";
            disk = "/";
          };
        }
        # Must stay the last widget: theme.css themes it by position,
        # since Homepage gives info widgets no id or class hook.
        {
          resources = {
            label = "Companion Cube";
            disk = "/mnt/media";
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
      + builtins.readFile ./theme.js;

      # @import must stay first in the stylesheet, so the mask is appended.
      customCSS = builtins.readFile ./theme.css + ''
        :root {
          --aperture-iris: url("${iris "black"}");
          --companion-cube: url("${companionCube}");
        }
      '';
    };

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts.dashboard = {
        default = true;
        locations."/".proxyPass = "http://127.0.0.1:${toString homepagePort}";
      };
    };
    homelab.services.homepage = {
      port = 80;
      expose = "tailnet";
    };

  };

}
