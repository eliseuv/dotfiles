{ pkgs, ... }:
{

  programs.waybar = {
    enable = true;
    systemd.enable = true;
  };

  home.packages = with pkgs; [

    # Weather info
    wttrbar

    # Font
    nerd-fonts.ubuntu

  ];

  # Modules
  home.file.".config/waybar/modules.json".source = ./modules.json;

  # Styling
  home.file.".config/waybar/style.css".source = ./style.css;

}
