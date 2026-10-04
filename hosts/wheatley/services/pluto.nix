# Pluto notebooks, here and on GLaDOS, started and stopped from Dev tiles and
# opened through the dashboard's nginx behind its login (dashboard/controls.nix
# adds it for the tiles' paths); the units are modules/nixos/services/pluto.
# nginx hands each Pluto its secret as the cookie Pluto would otherwise set
# after a ?secret= visit, so the tile is a plain link. Pluto only uses that
# cookie, so replacing the browser's Cookie header loses nothing.
{ config, ... }:
let
  cfg = config.my.services.pluto;
  glados = {
    basePath = "/glados/pluto/";
    # Her tailnet address, as for her terminal (system.nix): nginx resolves
    # upstream names once at startup. Port is her my.services.pluto.port.
    upstream = "http://100.110.170.42:1234";
  };

  cookieTemplate = secret: {
    content = ''
      proxy_set_header Cookie "secret=${config.sops.placeholder.${secret}}";
    '';
    owner = config.services.nginx.user;
    restartUnits = [ "nginx.service" ];
  };

  # Long read timeout so an idle notebook's websocket isn't cut after nginx's
  # default 60s. No URI on proxyPass: Pluto serves under its base path itself.
  location = upstream: template: {
    proxyPass = upstream;
    proxyWebsockets = true;
    extraConfig = ''
      proxy_read_timeout 1d;
      include ${config.sops.templates.${template}.path};
    '';
  };
in
{

  my.services.pluto = {
    enable = true;
    basePath = "/wheatley/pluto/";
  };

  # This host's own pluto/secret is declared by the Pluto module; GLaDOS's is a
  # copy of the one in secrets/GLaDOS.yaml.
  sops.secrets."pluto/glados-secret" = { };
  sops.templates."pluto-cookie-wheatley.conf" = cookieTemplate "pluto/secret";
  sops.templates."pluto-cookie-glados.conf" = cookieTemplate "pluto/glados-secret";

  services.nginx.virtualHosts.dashboard.locations = {
    ${cfg.basePath} = location "http://127.0.0.1:${toString cfg.port}" "pluto-cookie-wheatley.conf";
    ${glados.basePath} = location glados.upstream "pluto-cookie-glados.conf";
  };

  homelab.services = {
    pluto-wheatley.dashboard = {
      name = "Pluto · Wheatley";
      group = "Dev";
      order = 0;
      description = "Julia notebooks on Wheatley";
      icon = "si-julia";
      href = cfg.basePath;
      unit = "pluto.service";
    };
    pluto-glados.dashboard = {
      name = "Pluto · GLaDOS";
      group = "Dev";
      order = 0;
      description = "Julia notebooks on GLaDOS";
      icon = "si-julia";
      href = glados.basePath;
      unit = "pluto.service";
      unitHost = "GLaDOS";
    };
  };

}
