{ config, lib, ... }:
{

  config = lib.mkIf config.my.secrets.user.enable {

    programs.password-store = {
      enable = true;
      settings = {
        PASSWORD_STORE_DIR = "$XDG_DATA_HOME/password-store";
      };
    };

  };

}
