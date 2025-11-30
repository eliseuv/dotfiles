{ ... }:
{

  imports = [
    ./ghostty.nix
    ./kitty.nix
  ];

  # Default terminal environment variables
  home.sessionVariables = {
    TERMINAL = "ghostty";
    TERM = "xterm-ghostty";
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

}
