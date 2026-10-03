{ config, lib, ... }:
{

  config = lib.mkIf config.my.home.apps.enable {

    programs.ledger = {
      enable = true;
      settings = {
        sort = "date";
        strict = true;
      };
    };

  };

}
