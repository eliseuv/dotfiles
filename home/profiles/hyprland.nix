{ ... }:
{

  imports = [
    # Window Manager
    ../desktop/window-manager/hyprland/default.nix

    # Bar
    ../desktop/bar/waybar/default.nix

    # Menu
    ../desktop/menu/rofi/default.nix

    # Services
    ../desktop/services/dunst.nix
    ../desktop/services/hyprpaper.nix
    ../desktop/services/hypridle.nix
    ../desktop/services/hyprlock.nix
    ../desktop/services/hyprpolkitagent.nix

    # Notify time every hour
    ../services/notify-clock.nix
  ];

}
