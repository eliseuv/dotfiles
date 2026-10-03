{ config, lib, ... }:
{

  config = lib.mkIf config.my.services.tailscale.enable {

    services.tailscale = {
      enable = true;
      # Lets the user run `tailscale up/down` without root (used by the waybar toggle)
      extraSetFlags = [ "--operator=${config.my.host.primaryUser}" ];
    };

  };

}
