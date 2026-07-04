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
    ./browser/firefox/vanilla.nix

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

    # chell specific
    ./services/syncthing/folders/chell.nix
    # Minecraft
    ./games/minecraft.nix
    # Retroarch
    ./games/retroarch.nix
    ./extra/rclone/default.nix

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

  programs.git.settings.safe.directory = [ "/etc/dotfiles" ];

  fonts.fontconfig = {
    enable = true;
  };

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";

}
