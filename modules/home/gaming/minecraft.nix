{ config, lib, ... }:
{

  config = lib.mkIf config.my.gaming.enable {

    programs.prismlauncher = {
      enable = true;
    };

  };

}
