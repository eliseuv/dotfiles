# Media stack: qBittorrent (download client) -> Sonarr/Radarr (library
# management) <- Prowlarr (indexers) -> Jellyfin (playback) <- Seerr (requests).
# All native NixOS services, bound wide open on the LAN like this host's other
# services (see ledger-web.nix) - Tailscale is the remote-access layer, there
# is no reverse proxy. Downloads and library share one NFS mount (nas.nix) so
# Sonarr/Radarr imports are hardlinks, not cross-device copies; service state
# (SQLite) stays on local disk under /var/lib.
{ lib, ... }:
let
  mediaRoot = "/mnt/media";
  mediaServices = [ "qbittorrent" "sonarr" "radarr" "jellyfin" ];
in
{

  # Pinned: NFS passes numeric IDs through, so this must stay stable for
  # ownership on the NAS to keep meaning the same group.
  users.groups.media.gid = 982;

  # Not tmpfiles: systemd-tmpfiles-setup runs before the network is up and
  # would stall on the automount.
  systemd.services = {
    media-dirs = {
      description = "Create media directories on the NAS share";
      unitConfig.RequiresMountsFor = mediaRoot;
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      script = ''
        install -d -m 2775 -o root -g media \
          ${mediaRoot}/downloads ${mediaRoot}/library/tv ${mediaRoot}/library/movies
      '';
    };
  }
  # Hard dependency: if the NAS is down these must not start and write into
  # the bare mountpoint on the root filesystem.
  // lib.genAttrs mediaServices (_: {
    requires = [ "media-dirs.service" ];
    after = [ "media-dirs.service" ];
    unitConfig.RequiresMountsFor = mediaRoot;
  });

  services.qbittorrent = {
    enable = true;
    webuiPort = 8080;
    torrentingPort = 51413;
    openFirewall = true;
    serverConfig.Preferences.Downloads.SavePath = "${mediaRoot}/downloads";
  };
  users.users.qbittorrent.extraGroups = [ "media" ];
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
