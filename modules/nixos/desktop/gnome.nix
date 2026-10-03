{ config, lib, ... }:
{

  config = lib.mkIf config.my.desktop.gnome.enable {

    services.desktopManager.gnome = {
      enable = true;
    };

  };

}
