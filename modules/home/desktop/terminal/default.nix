{ config, lib, ... }:
{

  config = lib.mkIf config.my.desktop.enable {

    # Default terminal environment variables
    # (TERM is deliberately not set globally: each terminal sets its own)
    home.sessionVariables = {
      TERMINAL = "ghostty";
    };

    # Set default terminal emulator
    xdg.terminal-exec = {
      enable = true;
      settings = {
        default = [
          "ghostty.desktop"
        ];
      };
    };

  };

}
