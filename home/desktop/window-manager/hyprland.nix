{ pkgs, ... }:
{

  home.packages = with pkgs; [

    # Audio mixer
    pulsemixer

  ];

  # Default terminal
  programs.kitty.enable = true;

  # Clipboard manager
  services.copyq.enable = true;

  # Hyprland config
  home.file.".config/hypr/hyprland.conf".source = ./hyprland/hyprland.conf;

  # Catppuccin theme
  home.file.".config/hypr/catppuccin" = {
    source = ./hyprland/themes/catppuccin;
    recursive = true;
  };

  # Screenshot
  programs.hyprshot = {
    enable = true;
  };

}
