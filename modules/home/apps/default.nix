# Desktop apps that need no more than installing; the rest have a module
# each, by category.
{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.apps.enable {

    home.packages = with pkgs; [

      # Discord: Electron and TUI clients
      legcord
      discordo

      # Telegram: desktop and TUI clients
      telegram-desktop
      nchat

      # Vector graphics
      inkscape

      # LAN file sharing
      localsend

      # Torrents
      qbittorrent

      # Network monitor, and its runtime dependencies
      sniffnet
      libpcap
      alsa-lib
      fontconfig
      gtk3

    ];

    # Plain-text accounting
    programs.ledger = {
      enable = true;
      settings = {
        sort = "date";
        strict = true;
      };
    };

  };

}
