{ config, lib, ... }:
{

  config = lib.mkIf config.my.home.apps.enable {

    programs.feh = {
      enable = true;
    };

  };

}
