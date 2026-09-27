# Media stack: qBittorrent (download client) -> Sonarr/Radarr (library
# management) <- Prowlarr (indexers) -> Jellyfin (playback) <- Seerr (requests).
# All native NixOS services, bound wide open on the LAN like this host's other
# services (see ledger-web.nix) - Tailscale is the remote-access layer, there
# is no reverse proxy. Downloads and library share one NFS mount (nas.nix) so
# Sonarr/Radarr imports are hardlinks, not cross-device copies; service state
# (SQLite) stays on local disk under /var/lib.
{ config, lib, pkgs, ... }:
let
  mediaRoot = "/mnt/media";
  mediaServices = [ "qbittorrent" "sonarr" "radarr" "jellyfin" ];
in
{

  # Pinned: NFS passes numeric IDs through, so this must stay stable for
  # ownership on the NAS to keep meaning the same group.
  users.groups.media.gid = 982;
  users.users.evf.extraGroups = [ "media" ];

  # Not tmpfiles: systemd-tmpfiles-setup runs before the network is up and
  # would stall on the automount. The share root is included because a fresh
  # Synology shared folder carries only a DSM ACL, which NFS exposes as 000.
  systemd.services = lib.mkMerge [
    {
      media-dirs = {
        description = "Create media directories on the NAS share";
        unitConfig.RequiresMountsFor = mediaRoot;
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        script = ''
          install -d -m 2775 -o root -g media \
            ${mediaRoot} ${mediaRoot}/downloads ${mediaRoot}/library/tv ${mediaRoot}/library/movies
        '';
      };
    }
    # Hard dependency: if the NAS is down these must not start and write into
    # the bare mountpoint on the root filesystem.
    (lib.genAttrs mediaServices (_: {
      requires = [ "media-dirs.service" ];
      after = [ "media-dirs.service" ];
      unitConfig.RequiresMountsFor = mediaRoot;
    }))
    # The qBittorrent module reinstalls qBittorrent.conf from the store on
    # every start, so the API key (see below) is spliced in afterwards - same
    # user, so the file stays writable.
    {
      qbittorrent.serviceConfig.ExecStartPre = lib.mkAfter [
        (pkgs.writeShellScript "qbittorrent-inject-api-key" ''
          conf="${config.services.qbittorrent.profileDir}/qBittorrent/config/qBittorrent.conf"
          key=$(<${config.sops.secrets."qbittorrent/api-key".path})
          contents=$(<"$conf")
          printf '%s\n' "''${contents//@QBT_API_KEY@/$key}" > "$conf"
        '')
      ];
    }
    # FlareSolverr is an open proxy driving a headless browser, and Prowlarr
    # is its only client.
    { flaresolverr.environment.HOST = "127.0.0.1"; }
  ];

  services.qbittorrent = {
    enable = true;
    webuiPort = 8080;
    torrentingPort = 51413;
    openFirewall = true;
    serverConfig.Preferences = {
      Downloads.SavePath = "${mediaRoot}/downloads";
      # Substituted from sops below, keeping the key out of the Nix store.
      WebUI.APIKey = "@QBT_API_KEY@";
    };
  };
  users.users.qbittorrent.extraGroups = [ "media" ];

  # API key for the WebUI (Authorization: Bearer), used by the dashboard.
  # qBittorrent requires the form qbt_ + 28 alphanumerics; anything else is
  # silently ignored.
  sops.secrets."qbittorrent/api-key" = {
    sopsFile = ../../../secrets/wheatley.yaml;
    owner = config.services.qbittorrent.user;
    restartUnits = [ "qbittorrent.service" ];
  };
  # qBittorrent's openFirewall only opens the TCP side of each port.
  networking.firewall.allowedUDPPorts = [ 51413 ];

  services.sonarr.enable = true;
  services.sonarr.openFirewall = true;
  users.users.sonarr.extraGroups = [ "media" ];

  services.radarr.enable = true;
  services.radarr.openFirewall = true;
  users.users.radarr.extraGroups = [ "media" ];

  services.prowlarr.enable = true;
  services.prowlarr.openFirewall = true;

  # Pin each *arr's API key to the sops copy (declared in dashboard.nix)
  # instead of the one it generated on first start, so the keys the dashboard
  # and the cross-service wiring use can't drift from the apps'.
  sops.templates = lib.genAttrs [ "sonarr.env" "radarr.env" "prowlarr.env" ] (
    file:
    let
      service = lib.removeSuffix ".env" file;
    in
    {
      content = "${lib.toUpper service}__AUTH__APIKEY=${config.sops.placeholder."homepage/${service}"}";
      restartUnits = [ "${service}.service" ];
    }
  );
  services.sonarr.environmentFiles = [ config.sops.templates."sonarr.env".path ];
  services.radarr.environmentFiles = [ config.sops.templates."radarr.env".path ];
  services.prowlarr.environmentFiles = [ config.sops.templates."prowlarr.env".path ];

  # Cloudflare challenge solver for Prowlarr, used by indexers tagged
  # "flaresolverr" (see arr-sync). Bound to loopback in systemd.services
  # above.
  services.flaresolverr.enable = true;

  services.jellyfin.enable = true;
  services.jellyfin.openFirewall = true;
  users.users.jellyfin.extraGroups = [ "media" ];

  # configDir defaults to the pre-26.05 jellyseerr path here, since it's
  # keyed off system.stateVersion (24.11 on this host), not the nixpkgs
  # version - just a directory name, doesn't affect functionality.
  services.seerr = {
    enable = true;
    openFirewall = true;
  };

}
