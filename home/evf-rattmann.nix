{ pkgs, inputs, ... }:
{

  imports = [

    # Shell environment
    ./shell/default.nix

    # Authentication
    # GnuPG
    ./auth/gpg.nix
    # SSH
    ./auth/ssh.nix
    # Standard Unix Password Manager
    ./auth/password-store.nix
    # SOPS
    ./auth/sops.nix

    # Maintenance
    ./maintenance/default.nix

    # Development
    ./development/default.nix

    # Containers
    ./containers/default.nix

    # Text editors (TUI only)
    ./editor/neovim/default.nix
    ./editor/helix.nix

    # Services (headless only)
    ./services/pueue.nix
    ./services/syncthing/default.nix

    # User services
    # Automount
    ./services/udiskie.nix
    # Notify time every hour
    ./services/notify-clock.nix

    # Terminal emulators
    ./terminal/default.nix

    # Web browsers
    ./browser/default.nix

    # Desktop
    ./desktop/i3.nix

    # Theming
    # GTK
    ./theme/gtk.nix
    # QT
    ./theme/qt.nix
    # Catppuccin
    ./theme/catppuccin.nix
    # Xresources
    ./theme/xresources.nix

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

  home = {
    username = "evf";
    homeDirectory = "/home/evf";
  };

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";

}
