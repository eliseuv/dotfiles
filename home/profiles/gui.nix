{ pkgs, ... }:
{

  imports = [

    # Terminal emulators
    ../terminal/default.nix

    # Web browsers (Firefox flavor is chosen per host)
    ../browser/default.nix

    # Automount
    ../services/udiskie.nix

    # Theming
    ../theme/gtk.nix
    ../theme/qt.nix
    ../theme/catppuccin.nix
    ../theme/xresources.nix

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
