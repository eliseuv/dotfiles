{ pkgs, ... }:
{

  home.packages = with pkgs; [

    # Distrobox
    distrobox
    distrobox-tui

  ];

}
