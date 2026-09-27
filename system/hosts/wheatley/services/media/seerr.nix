# Seerr: media requests, handed on to Sonarr/Radarr. Reachable from the
# tailnet so requests can be made away from home.
{ config, ... }:
{

  # configDir defaults to the pre-26.05 jellyseerr path here, since it's
  # keyed off system.stateVersion (24.11 on this host), not the nixpkgs
  # version - just a directory name, doesn't affect functionality.
  services.seerr.enable = true;
  homelab.services.seerr = {
    port = config.services.seerr.port;
    expose = "tailnet";
  };

}
