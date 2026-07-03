{ ... }:
{

  imports = [
    # Window Manager
    ./window-manager/i3/default.nix

    # Menu
    ./menu/rofi/default.nix

    # Services
    ./services/dunst.nix
  ];

}
