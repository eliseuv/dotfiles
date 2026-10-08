# Bazarr: subtitles for the Sonarr/Radarr libraries, written next to the media
# files. Wired to both through settings, which override whatever the web UI
# saved; the API keys come from the same sops secrets the *arrs are pinned to.
{ config, ... }:
{

  services.bazarr = {
    enable = true;
    settings = {
      general = {
        use_sonarr = true;
        use_radarr = true;
      };
      auth.apikey._secret = config.sops.secrets."bazarr/api-key".path;
      sonarr = {
        ip = "127.0.0.1";
        port = config.services.sonarr.settings.server.port;
        apikey._secret = config.sops.secrets."sonarr/api-key".path;
      };
      radarr = {
        ip = "127.0.0.1";
        port = config.services.radarr.settings.server.port;
        apikey._secret = config.sops.secrets."radarr/api-key".path;
      };
    };
  };
  # Writes subtitle files into the library on the share (default.nix pins the
  # NAS dependency).
  users.users.bazarr.extraGroups = [ "media" ];

  # Read through LoadCredential, so root-owned is enough.
  sops.secrets."bazarr/api-key".restartUnits = [ "bazarr.service" ];

  homelab.services.bazarr = {
    port = config.services.bazarr.settings.general.port;
    dashboard = {
      name = "Bazarr";
      group = "Media";
      order = 7;
      description = "Subtitles";
      icon = "bazarr.png";
      widget.type = "bazarr";
      widgetKey = "bazarr/api-key";
      unit = "bazarr.service";
    };
  };

}
