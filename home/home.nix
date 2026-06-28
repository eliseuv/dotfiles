{ pkgs, inputs, ... }:
{

  imports = [

    # Headless (Core) environment
    ./headless.nix

    # User services
    ./services/default.nix

    # Terminal emulators
    ./terminal/default.nix

    # Text editors
    ./editor/default.nix

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
    ./social/default.nix

    # Desktop
    ./desktop/hyprland.nix

    # Extra
    ./extra/ledger.nix
    ./extra/inkscape.nix
    ./extra/qbittorrent.nix
    ./extra/localsend.nix
    ./extra/sniffnet.nix

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
