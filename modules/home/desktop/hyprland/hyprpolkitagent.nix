{ config, lib, ... }:
{

  config = lib.mkIf config.my.desktop.hyprland.enable {

    services.hyprpolkitagent = {
      enable = true;
    };

  };

}
