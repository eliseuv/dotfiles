{ pkgs, ... }:
{

  home.packages = with pkgs; [

    # Audio mixer
    wiremix

    # Look and feel
    picom
    feh
    
    # Utilities
    scrot
    brightnessctl
    xclip

  ];

  # i3 config
  xsession.windowManager.i3 = {
    enable = true;
    config = null;
    extraConfig = builtins.readFile ./catppuccin-mocha + "\n" + builtins.readFile ./config;
  };

  # Default terminal
  programs.kitty.enable = true;

  # Clipboard manager
  services.copyq.enable = true;

}
