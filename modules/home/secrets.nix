{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{

  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  config = lib.mkIf config.my.secrets.user.enable {

    home.packages = with pkgs; [
      age
      sops
    ];

    programs.password-store = {
      enable = true;
      settings = {
        PASSWORD_STORE_DIR = "$XDG_DATA_HOME/password-store";
      };
    };

    sops = {
      age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

      defaultSopsFile = ../../secrets/users + "/${config.home.username}.yaml";
      defaultSopsFormat = "yaml";

      secrets = {
        "alphavantage/api-key" = { };
        "deepseek/api-key" = { };
        "gemini/api-key" = { };
        "openweather/api-key" = { };
        "quandl/api-key" = { };
        "ntfy/topic" = { };
      };
    };

  };

}
