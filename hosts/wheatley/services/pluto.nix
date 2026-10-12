# Pluto notebooks, here, on GLaDOS and on chell, started and stopped from their hosts'
# ports menus and opened through the dashboard's nginx behind its login
# (dashboard/controls.nix adds it for the entries' paths); the units are
# modules/nixos/services/pluto. nginx hands each Pluto its secret as the
# cookie Pluto would otherwise set after a ?secret= visit, so the entry is a
# plain link. Pluto only uses that
# cookie, so replacing the browser's Cookie header loses nothing.
{ config, ... }:
let
  cfg = config.my.services.pluto;
  inherit (config.homelab.network) tailnet;
  glados = rec {
    basePath = "/glados/pluto/";
    # Her my.services.pluto.port.
    port = 1234;
    # By tailnet address, as for her terminal (system.nix): nginx resolves
    # upstream names once at startup.
    upstream = "http://${tailnet.GLaDOS}:${toString port}";
  };
  chell = rec {
    basePath = "/chell/pluto/";
    port = 1234;
    upstream = "http://${tailnet.chell}:${toString port}";
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

  # This host's own pluto/secret is declared by the Pluto module; GLaDOS's
  # and chell's are shared with them, under other names here so they don't
  # collide.
  sops.secrets."pluto/glados-secret" = {
    sopsFile = ../../../secrets/shared/pluto-GLaDOS.yaml;
    key = "pluto/secret";
  };
  sops.secrets."pluto/chell-secret" = {
    sopsFile = ../../../secrets/shared/pluto-chell.yaml;
    key = "pluto/secret";
  };
  sops.templates."pluto-cookie-wheatley.conf" = cookieTemplate "pluto/secret";
  sops.templates."pluto-cookie-glados.conf" = cookieTemplate "pluto/glados-secret";
  sops.templates."pluto-cookie-chell.conf" = cookieTemplate "pluto/chell-secret";

  services.nginx.virtualHosts.dashboard.locations = {
    ${cfg.basePath} = location "http://127.0.0.1:${toString cfg.port}" "pluto-cookie-wheatley.conf";
    ${glados.basePath} = location glados.upstream "pluto-cookie-glados.conf";
    ${chell.basePath} = location chell.upstream "pluto-cookie-chell.conf";
  };

  # The menus probe the port itself, which on GLaDOS and chell only wheatley
  # may reach.
  homelab.services = {
    wheatley.dashboard.ports.Pluto = {
      inherit (cfg) port;
      href = cfg.basePath;
      unit = "pluto.service";
    };
    glados.dashboard.ports.Pluto = {
      inherit (glados) port;
      href = glados.basePath;
      unit = "pluto.service";
    };
    chell.dashboard.ports.Pluto = {
      inherit (chell) port;
      href = chell.basePath;
      unit = "pluto.service";
    };
  };

}
