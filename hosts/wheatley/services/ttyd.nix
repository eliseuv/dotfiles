# Dashboard tile and firewall entry for the ttyd web terminal; the unit itself
# is modules/nixos/services/ttyd.nix.
{ config, ... }:
{

  my.services.ttyd.enable = true;

  homelab.services.terminal = {
    inherit (config.my.services.ttyd) port;
    expose = "tailnet";
    dashboard = {
      name = "Terminal";
      group = "Dev";
      order = 1;
      description = "ttyd web terminal";
      icon = "mdi-console";
      unit = "ttyd.service";
    };
  };

}
