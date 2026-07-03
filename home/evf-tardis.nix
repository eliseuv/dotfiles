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

    # Text editors
    # GUI
    ./editor/emacs/default.nix
    ./editor/vscode.nix
    ./editor/zed.nix
    ./editor/antigravity.nix

    # Web browsers
    ./browser/default.nix

    # Documents
    ./documents/default.nix

    # Media
    ./media/image/default.nix
    ./media/music/spotify.nix
    ./media/video/mpv.nix
    ./media/video/youtube.nix

    # Social
    ./social/telegram.nix
    ./social/discord.nix
    ./social/late.nix

    # Desktop
    ./desktop/hyprland.nix

    # Extra
    ./extra/ledger.nix
    ./extra/inkscape.nix
    ./extra/qbittorrent.nix
    ./extra/localsend.nix
    ./extra/sniffnet.nix

    # Theming
    # GTK
    ./theme/gtk.nix
    # QT
    ./theme/qt.nix
    # Catppuccin
    ./theme/catppuccin.nix
    # Xresources
    ./theme/xresources.nix

    # tardis specific
    ./services/syncthing/folders/tardis.nix
    ./desktop/bar/waybar/tardis/default.nix

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
