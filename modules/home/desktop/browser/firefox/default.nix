{
  config,
  lib,
  pkgs,
  inputs,
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
        profiles.${config.home.username}.userChrome =
          builtins.readFile "${inputs.firefox-qutebrowser-userchrome}/userChrome.css"
          + builtins.readFile ./userChrome-overrides.css;
      })
    ];

    # Copy tridactyl config
    home.file = lib.mkIf customUI {
      ".config/tridactyl/tridactylrc".source = ./tridactylrc;
    };

  };

}
