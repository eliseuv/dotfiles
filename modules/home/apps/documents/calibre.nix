{ config, lib, ... }:
{

  config = lib.mkIf config.my.home.apps.enable {

    programs.calibre = {
      enable = true;
    };

  };

}
