{ pkgs, config, ... }:
{

  programs.firefox = {
    enable = true;
    nativeMessagingHosts = [ pkgs.tridactyl-native ];
    configPath = "${config.xdg.configHome}/mozilla/firefox";
    profiles = {
      "evf" = {
        userChrome = builtins.readFile ./userChrome.css;
      };
    };
  };

  # Copy tridactyl config
  home.file = {
    ".config/tridactyl/tridactylrc".source = ./tridactylrc;
  };

}
