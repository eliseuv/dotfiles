{ config, lib, ... }:
{

  config = lib.mkIf config.my.desktop.i3.enable {

    services.xserver = {
      enable = true;
      desktopManager = {
        xterm.enable = false;
      };
      windowManager.i3 = {
        enable = true;
      };
    };

  };

}
