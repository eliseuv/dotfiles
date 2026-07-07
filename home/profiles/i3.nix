{ ... }:
{

  imports = [
    # Window Manager
    ../desktop/window-manager/i3/default.nix

    # Menu
    ../desktop/menu/rofi/default.nix

    # Services
    ../desktop/services/dunst.nix
  ];

}
