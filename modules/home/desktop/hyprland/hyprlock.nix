{ config, lib, ... }:
{

  config = lib.mkIf config.my.desktop.hyprland.enable {

    programs.hyprlock = {
      enable = true;
    };

    catppuccin.hyprlock = {
      enable = true;
    };

  };

}
