{ pkgs, hostName, ... }:
{

  programs.waybar = {
    enable = true;
  };

  home.packages = with pkgs; [

    # Weather info
    wttrbar

    # Claude usage widget deps
    curl
    jq

    # Font
    nerd-fonts.ubuntu

  ];

  # Per-host bar layout
  home.file.".config/waybar/config.jsonc".source = ./config/${hostName}.jsonc;

  # Modules
  home.file.".config/waybar/modules.json".source = ./modules.json;

  # Styling
  home.file.".config/waybar/style.css".source = ./style.css;

  # Copy scripts
  home.file.".config/waybar/scripts/check_flake_updates.sh".source = ./check_flake_updates.sh;
  home.file.".config/waybar/scripts/claude_usage.sh".source = ./claude_usage.sh;

}
