{ pkgs, ... }:
{

  home.packages = with pkgs; [

    # Audio mixer
    wiremix

  ];

  # Hyprland config
  home.file.".config/hypr/hyprland.conf".source = ./hyprland.conf;

  # Catppuccin theme
  catppuccin.hyprland = {
    enable = true;
  };

  # Default terminal
  programs.kitty.enable = true;

  # Clipboard manager
  services.copyq.enable = true;

  # Screenshot
  programs.hyprshot = {
    enable = true;
    saveLocation = "$HOME/Storage/Images/screenshots";
  };

}
