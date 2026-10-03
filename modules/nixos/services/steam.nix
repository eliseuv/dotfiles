{ config, lib, ... }:
{

  config = lib.mkIf config.my.gaming.enable {

    programs.steam = {
      enable = true;
      protontricks.enable = true;
      localNetworkGameTransfers.openFirewall = true;
    };

  };

}
