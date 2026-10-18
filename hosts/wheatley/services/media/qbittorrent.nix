# qBittorrent: the download client Sonarr, Radarr and Lidarr hand torrents to.
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
      WebUI.Username = "evf";
      # Without this, a password set in the WebUI is lost on the next start.
      WebUI.Password_PBKDF2 = "@QBT_PASSWORD_PBKDF2@";
      # Lidarr's qBittorrent client has no API key field (Sonarr's and
      # Radarr's do), so it connects unauthenticated over localhost. This
      # opens the WebUI to every local process; the LAN and tailnet still need
      # the key. Revisit once Lidarr gains API key support.
      WebUI.LocalHostAuth = false;
    };
  };
  users.users.qbittorrent.extraGroups = [ "media" ];

  # The qBittorrent module reinstalls qBittorrent.conf from the store on every
  # start, so the secrets are spliced in afterwards - same user, so the file
  # stays writable.
  systemd.services.qbittorrent.serviceConfig.ExecStartPre = lib.mkAfter [
    (pkgs.writeShellScript "qbittorrent-inject-secrets" ''
      conf="${config.services.qbittorrent.profileDir}/qBittorrent/config/qBittorrent.conf"
      key=$(<${config.sops.secrets."qbittorrent/api-key".path})
      password=$(<${config.sops.secrets."qbittorrent/password-pbkdf2".path})
      contents=$(<"$conf")
      contents=''${contents//@QBT_API_KEY@/$key}
      contents=''${contents//@QBT_PASSWORD_PBKDF2@/$password}
      printf '%s\n' "$contents" > "$conf"
    '')
  ];

  # API key for the WebUI (Authorization: Bearer), used by the dashboard and
  # by Sonarr/Radarr (arr-sync.nix). qBittorrent requires the form qbt_ + 28
  # alphanumerics; anything else is silently ignored.
  sops.secrets."qbittorrent/api-key" = {
    owner = config.services.qbittorrent.user;
    restartUnits = [ "qbittorrent.service" "arr-sync.service" ];
  };

  # PBKDF2 hash of the WebUI password, in qBittorrent's @ByteArray(salt:hash)
  # form.
  sops.secrets."qbittorrent/password-pbkdf2" = {
    owner = config.services.qbittorrent.user;
    restartUnits = [ "qbittorrent.service" ];
  };

  homelab.services.qbittorrent = {
    port = config.services.qbittorrent.webuiPort;
    dashboard = {
      name = "qBittorrent";
      group = "Media";
      order = 3;
      description = "Download client";
      icon = "qbittorrent.svg";
      widget.type = "qbittorrent";
      widgetKey = "qbittorrent/api-key";
      unit = "qbittorrent.service";
    };
  };
  # The one thing open to everyone: peers must reach it.
  homelab.services.torrent = {
    port = config.services.qbittorrent.torrentingPort;
    expose = "public";
    udp = true;
  };

}
