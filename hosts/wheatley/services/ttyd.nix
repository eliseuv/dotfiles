# The ttyd web terminal, served under the dashboard's nginx at
# /wheatley/terminal/ behind its login, and opened from Wheatley's host tile
# (system.nix); the unit itself is modules/nixos/services/ttyd.nix. Bound to
# loopback so nginx is the only way in.
{ config, ... }:
let
  cfg = config.my.services.ttyd;
in
{

  my.services.ttyd = {
    enable = true;
    basePath = "/wheatley/terminal";
    interface = "lo";
  };

  # Long read timeout so an idle terminal's websocket isn't cut after nginx's
  # default 60s.
  services.nginx.virtualHosts.dashboard.locations."${cfg.basePath}/" = {
    proxyPass = "http://127.0.0.1:${toString cfg.port}";
    proxyWebsockets = true;
    extraConfig = ''
      proxy_read_timeout 1d;
    '';
  };

}
