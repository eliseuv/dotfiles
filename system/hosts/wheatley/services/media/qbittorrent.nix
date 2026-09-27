# qBittorrent: the download client Sonarr and Radarr hand torrents to.
{ config, lib, pkgs, ... }:
let
  mediaRoot = config.homelab.media.root;
in
{

  services.qbittorrent = {
    enable = true;
    webuiPort = 8080;
    torrentingPort = 51413;
    serverConfig.Preferences = {
      Downloads.SavePath = "${mediaRoot}/downloads";
      # Substituted from sops below, keeping the key out of the Nix store.
      WebUI.APIKey = "@QBT_API_KEY@";
    };
  };
  users.users.qbittorrent.extraGroups = [ "media" ];

  # The qBittorrent module reinstalls qBittorrent.conf from the store on every
  # start, so the API key is spliced in afterwards - same user, so the file
  # stays writable.
  systemd.services.qbittorrent.serviceConfig.ExecStartPre = lib.mkAfter [
    (pkgs.writeShellScript "qbittorrent-inject-api-key" ''
      conf="${config.services.qbittorrent.profileDir}/qBittorrent/config/qBittorrent.conf"
      key=$(<${config.sops.secrets."qbittorrent/api-key".path})
      contents=$(<"$conf")
      printf '%s\n' "''${contents//@QBT_API_KEY@/$key}" > "$conf"
    '')
  ];

  # API key for the WebUI (Authorization: Bearer), used by the dashboard and
  # by Sonarr/Radarr (arr-sync.nix). qBittorrent requires the form qbt_ + 28
  # alphanumerics; anything else is silently ignored.
  sops.secrets."qbittorrent/api-key" = {
    owner = config.services.qbittorrent.user;
    restartUnits = [ "qbittorrent.service" "arr-sync.service" ];
  };

  # The torrent port is the one thing open to everyone: peers must reach it.
  # Forced so it also drops the 5173 (vite) that the shared
  # system/hardware/network.nix opens to everyone; wheatley keeps that one
  # LAN-only (configuration.nix).
  networking.firewall.allowedTCPPorts = lib.mkForce [ config.services.qbittorrent.torrentingPort ];
  networking.firewall.allowedUDPPorts = [ config.services.qbittorrent.torrentingPort ];
  networking.firewall.lan.allowedTCPPorts = [ config.services.qbittorrent.webuiPort ];

}
