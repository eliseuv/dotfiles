{ ... }:
{

  imports = [
    # Window Manager
    ./window-manager/hyprland/default.nix

    # Bar
    ./bar/waybar/default.nix

    # Menu
    ./menu/rofi/default.nix

    # Services
    ./services/hyprpaper.nix
    ./services/hypridle.nix
    ./services/hyprlock.nix
    ./services/dunst.nix
  ];

}
