{ config, lib, ... }:
{

  config = lib.mkIf config.my.home.apps.enable {

    programs.zathura = {
      enable = true;
      mappings = {
        "<C-i>" = "recolor";
      };
      options = {
        recolor = true;
      };
    };

  };

}
