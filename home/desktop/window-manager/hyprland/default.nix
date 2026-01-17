{ pkgs, ... }:
{

  home.packages = with pkgs; [

    # Audio mixer
    wiremix

  ];

  # Default terminal
  programs.kitty.enable = true;

  # Clipboard manager
  services.copyq.enable = true;

  # Hyprland config
  home.file.".config/hypr/hyprland.conf".source = ./hyprland.conf;

  # Catppuccin theme
  home.file.".config/hypr/catppuccin" = {
    source = ./themes/catppuccin;
    recursive = true;
  };

  # Screenshot
  programs.hyprshot = {
    enable = true;
    saveLocation = "$HOME/Pictures/screenshots/";
  };

}
