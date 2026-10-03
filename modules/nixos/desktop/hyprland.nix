{ config, lib, ... }:
{

  config = lib.mkIf config.my.desktop.hyprland.enable {

    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };

  };

}
