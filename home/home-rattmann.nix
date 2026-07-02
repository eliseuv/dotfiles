{ pkgs, inputs, ... }:
{

  imports = [

    # Headless (Core) environment
    ./headless.nix

    # User services
    ./services/default.nix

    # Terminal emulators
    ./terminal/default.nix

    # Web browsers
    ./browser/default.nix

    # Desktop
    ./desktop/i3.nix

    # Theming
    ./theme/default.nix

  ];

  home.packages = with pkgs; [

    # Encryption
    cryptsetup
    veracrypt

    # File manager
    nautilus

    # Calculator
    speedcrunch

  ];

  fonts.fontconfig = {
    enable = true;
  };

}
