# Sonarr (TV), Radarr (movies) and Prowlarr (indexers), plus FlareSolverr for
# Prowlarr. How they're wired to each other lives in arr-sync.nix.
{ config, lib, ... }:
{

  services.sonarr.enable = true;
  users.users.sonarr.extraGroups = [ "media" ];

  services.radarr.enable = true;
  users.users.radarr.extraGroups = [ "media" ];

  services.prowlarr.enable = true;

  networking.firewall.lan.allowedTCPPorts = [
    config.services.sonarr.settings.server.port
    config.services.radarr.settings.server.port
    config.services.prowlarr.settings.server.port
  ];

  # Pin each *arr's API key to the sops copy (declared in ../dashboard)
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
  # "flaresolverr" (see arr-sync.nix). Loopback-only: it's an open proxy
  # driving a headless browser, and Prowlarr is its only client.
  services.flaresolverr.enable = true;
  systemd.services.flaresolverr.environment.HOST = "127.0.0.1";

}
