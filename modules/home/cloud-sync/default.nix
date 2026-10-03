{ config, lib, ... }:
{

  config = lib.mkIf config.my.home.cloudSync.enable {

    programs.rclone = {
      enable = true;
    };

  };

}
