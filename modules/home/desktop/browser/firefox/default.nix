{
  config,
  lib,
  pkgs,
  ...
}:
let
  customUI = config.my.home.firefox.customUI;
in
{

  config = lib.mkIf config.my.desktop.enable {

    programs.firefox = lib.mkMerge [
      {
        enable = true;
        configPath = "${config.xdg.configHome}/mozilla/firefox";
      }
      (lib.mkIf customUI {
        nativeMessagingHosts = [ pkgs.tridactyl-native ];
        profiles.${config.home.username}.userChrome = builtins.readFile ./userChrome.css;
      })
    ];

    # Copy tridactyl config
    home.file = lib.mkIf customUI {
      ".config/tridactyl/tridactylrc".source = ./tridactylrc;
    };

  };

}
