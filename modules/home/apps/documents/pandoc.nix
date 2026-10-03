{ config, lib, ... }:
{

  config = lib.mkIf config.my.home.apps.enable {

    programs.pandoc = {
      enable = true;
    };

  };

}
