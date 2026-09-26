# Media stack: qBittorrent (download client) -> Sonarr/Radarr (library
# management) <- Prowlarr (indexers) -> Jellyfin (playback) <- Seerr (requests).
# All native NixOS services, bound wide open on the LAN like this host's other
# services (see ledger-web.nix) - Tailscale is the remote-access layer, there
# is no reverse proxy. No storage mount exists on wheatley yet, so the library
# lives under /var/lib/media on the root filesystem.
{ ... }:
{

  users.groups.media = { };

  systemd.tmpfiles.settings."10-media-server" = {
    "/var/lib/media/downloads"."d" = {
      mode = "2775";
      user = "root";
      group = "media";
    };
    "/var/lib/media/library/tv"."d" = {
      mode = "2775";
      user = "root";
      group = "media";
    };
    "/var/lib/media/library/movies"."d" = {
      mode = "2775";
      user = "root";
      group = "media";
    };
  };

  services.qbittorrent = {
    enable = true;
    webuiPort = 8080;
    torrentingPort = 51413;
    openFirewall = true;
    serverConfig.Preferences.Downloads.SavePath = "/var/lib/media/downloads";
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
