{ ... }:
{

  imports = [

    # Text editors (GUI)
    ../editor/emacs/default.nix
    ../editor/vscode.nix
    ../editor/zed.nix

    # Documents
    ../documents/default.nix

    # Media
    ../media/image/default.nix
    ../media/music/spotify.nix
    ../media/video/mpv.nix
    ../media/video/youtube.nix

    # Social
    ../social/telegram.nix
    ../social/discord.nix

    # Extra
    ../extra/ledger.nix
    ../extra/inkscape.nix
    ../extra/qbittorrent.nix
    ../extra/localsend.nix
    ../extra/sniffnet.nix

  ];

}
