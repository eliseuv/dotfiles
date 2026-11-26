{ config, lib, ... }:
{

  config = lib.mkIf (config.my.gaming.enable && config.my.gaming.steam.enable) {

    programs.steam = {
      enable = true;
      protontricks.enable = true;
      localNetworkGameTransfers.openFirewall = true;
    };

  };

}
