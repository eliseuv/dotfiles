# Homepage dashboard at http://<wheatley>/ linking every service on this host.
# Homepage stays on its default port behind nginx rather than binding :80
# itself - its unit drops all capabilities and runs in a private user
# namespace - and nginx is the natural place for a future reverse proxy.
#
# Widgets query services server-side over loopback; API keys come from sops
# (secrets/wheatley.yaml) through an env file rendered at activation.
{ config, ... }:
let
  # Links are written against this host and rewritten client-side (customJS)
  # to whatever name the dashboard was opened with - LAN IP, Tailscale name,
  # etc. - so one config works from anywhere without hardcoding either.
  linkHost = "wheatley";
  homepagePort = config.services.homepage-dashboard.listenPort;

  service =
    { port, description, icon, widget ? null }:
    {
      inherit description icon;
      href = "http://${linkHost}:${toString port}";
      siteMonitor = "http://127.0.0.1:${toString port}";
    }
    // (if widget == null then { } else { widget = { url = "http://127.0.0.1:${toString port}"; } // widget; });

  secret = name: "{{HOMEPAGE_VAR_${name}}}";

  # Generic 8-blade camera iris, used as the favicon and (as a CSS mask) the
  # header mark. Percent-encoded so it works as a data URI in both places.
  iris =
    fill:
    "data:image/svg+xml,"
    + builtins.replaceStrings [ "<" ">" "#" " " ] [ "%3C" "%3E" "%23" "%20" ] ''
      <svg xmlns='http://www.w3.org/2000/svg' viewBox='-50 -50 100 100'><mask id='m'><circle r='46' fill='white'/><polygon points='15,0 10.6,10.6 0,15 -10.6,10.6 -15,0 -10.6,-10.6 0,-15 10.6,-10.6'/><path stroke='black' stroke-width='4' d='M15 0L24.4 45.9M10.6 10.6L-15.2 49.7M0 15L-45.9 24.4M-10.6 10.6L-49.7 -15.2M-15 0L-24.4 -45.9M-10.6 -10.6L15.2 -49.7M0 -15L45.9 -24.4M10.6 -10.6L49.7 15.2'/></mask><circle r='46' fill='${fill}' mask='url(#m)'/></svg>'';
in
{

  sops.secrets = {
    "homepage/sonarr" = { };
    "homepage/radarr" = { };
    "homepage/prowlarr" = { };
    "homepage/jellyfin" = { };
    "homepage/seerr" = { };
    "homepage/qbittorrent/username" = { };
    "homepage/qbittorrent/password" = { };
  };
  sops.defaultSopsFile = ../../../secrets/wheatley.yaml;

  # Rendered root:0400; systemd reads EnvironmentFile before dropping to the
  # service's DynamicUser, so Homepage itself never needs file access.
  sops.templates."homepage-dashboard.env" = {
    content = ''
      HOMEPAGE_VAR_SONARR_KEY=${config.sops.placeholder."homepage/sonarr"}
      HOMEPAGE_VAR_RADARR_KEY=${config.sops.placeholder."homepage/radarr"}
      HOMEPAGE_VAR_PROWLARR_KEY=${config.sops.placeholder."homepage/prowlarr"}
      HOMEPAGE_VAR_JELLYFIN_KEY=${config.sops.placeholder."homepage/jellyfin"}
      HOMEPAGE_VAR_SEERR_KEY=${config.sops.placeholder."homepage/seerr"}
      HOMEPAGE_VAR_QBITTORRENT_USERNAME=${config.sops.placeholder."homepage/qbittorrent/username"}
      HOMEPAGE_VAR_QBITTORRENT_PASSWORD=${config.sops.placeholder."homepage/qbittorrent/password"}
    '';
    restartUnits = [ "homepage-dashboard.service" ];
  };

  services.homepage-dashboard = {
    enable = true;
    environmentFiles = [ config.sops.templates."homepage-dashboard.env".path ];

    # Host header check (DNS-rebinding guard). nginx forwards the browser's
    # Host, which on :80 carries no port.
    allowedHosts = builtins.concatStringsSep "," [
      linkHost
      "wheatley-1"
      "wheatley.local"
      "wheatley.taild628c9.ts.net"
      "wheatley-1.taild628c9.ts.net"
      "192.168.0.62"
      "100.97.1.97"
    ];

    settings = {
      title = "Aperture Science · Wheatley";
      favicon = iris "#ff9a00";
      # Pinned so dashboard-theme.css can override this palette's variables.
      # theme is left unset: dashboard-theme.js drives the hidden toggle.
      color = "zinc";
      headerStyle = "clean";
      layout = {
        Media = { style = "row"; columns = 3; };
        Management = { style = "row"; columns = 4; };
        Tools = { style = "row"; columns = 3; };
      };
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
          label = "Storage";
          disk = [ "/" "/mnt/media" ];
        };
      }
    ];

    services = [
      {
        Media = [
          {
            Jellyfin = service {
              port = 8096;
              description = "Media server";
              icon = "jellyfin.png";
              widget = {
                type = "jellyfin";
                key = secret "JELLYFIN_KEY";
                enableBlocks = true;
              };
            };
          }
          {
            Seerr = service {
              port = config.services.seerr.port;
              description = "Media requests";
              icon = "jellyseerr.png";
              widget = {
                type = "seerr";
                key = secret "SEERR_KEY";
              };
            };
          }
          {
            qBittorrent = service {
              port = config.services.qbittorrent.webuiPort;
              description = "Download client";
              icon = "qbittorrent.png";
              widget = {
                type = "qbittorrent";
                username = secret "QBITTORRENT_USERNAME";
                password = secret "QBITTORRENT_PASSWORD";
              };
            };
          }
        ];
      }
      {
        Management = [
          {
            Sonarr = service {
              port = config.services.sonarr.settings.server.port;
              description = "TV shows";
              icon = "sonarr.png";
              widget = {
                type = "sonarr";
                key = secret "SONARR_KEY";
              };
            };
          }
          {
            Radarr = service {
              port = config.services.radarr.settings.server.port;
              description = "Movies";
              icon = "radarr.png";
              widget = {
                type = "radarr";
                key = secret "RADARR_KEY";
              };
            };
          }
          {
            Prowlarr = service {
              port = config.services.prowlarr.settings.server.port;
              description = "Indexers";
              icon = "prowlarr.png";
              widget = {
                type = "prowlarr";
                key = secret "PROWLARR_KEY";
              };
            };
          }
        ];
      }
      {
        Tools = [
          # Another host, so not built with `service`: a fixed LAN address the
          # retarget script leaves alone (same IP as the NFS mount in nas.nix).
          # DSM's cert is self-signed; Homepage's monitor doesn't verify it.
          {
            "Companion Cube" = {
              href = "https://192.168.0.35:5001";
              siteMonitor = "https://192.168.0.35:5001";
              description = "Synology NAS (DSM)";
              icon = "synology.png";
            };
          }
          {
            Ledger = service {
              port = 3001;
              description = "Ledger web app";
              icon = "mdi-cash-multiple";
            };
          }
          {
            Terminal = service {
              port = 3000;
              description = "ttyd web terminal";
              icon = "mdi-console";
            };
          }
          # Ad-hoc dev servers: the status dot shows whether one is running.
          {
            Zola = service {
              port = 1111;
              description = "Zola dev server";
              icon = "mdi-web";
            };
          }
          {
            Vite = service {
              port = 5173;
              description = "Vite dev server";
              icon = "mdi-lightning-bolt";
            };
          }
        ];
      }
    ];

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
    + builtins.readFile ./dashboard-theme.js;

    # @import must stay first in the stylesheet, so the mask is appended.
    customCSS = builtins.readFile ./dashboard-theme.css + ''
      :root { --aperture-iris: url("${iris "black"}"); }
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
  networking.firewall.allowedTCPPorts = [ 80 ];

}
