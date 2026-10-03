{ config, lib, ... }:
{

  config = lib.mkIf config.my.desktop.enable {

    qt = {
      enable = true;
      style.name = "adwaita-dark";
    };

  };

}
