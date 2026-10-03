{
  config,
  pkgs,
  lib,
  ...
}:
let

  hostName = config.my.host.name;

  # One layout shared by every host so bars can't drift apart; hosts only
  # differ in hardware-specific modules and in their outputs.
  hasHomePartition = hostName == "GLaDOS";
  hasBluetooth = hostName == "tardis";

  mainBar = {
    layer = "top";
    include = [ "~/.config/waybar/modules.json" ];
    modules-left = [
      "custom/launcher"
      "cpu"
      "memory"
      "disk"
    ]
    ++ lib.optional hasHomePartition "disk#home"
    ++ [ "temperature" ];
    modules-center = [
      "hyprland/workspaces"
      "tray"
    ];
    modules-right = [
      "privacy"
      # "custom/flake"
      "custom/claude-usage"
      "hyprland/language"
      "network"
      "custom/tailscale"
    ]
    ++ lib.optional hasBluetooth "bluetooth"
    ++ [
      "backlight"
      "pulseaudio"
      "battery"
      "custom/weather"
      "clock"
      "custom/power"
    ];
  };

  # Launcher and power menu live on the primary monitor only
  secondaryBar = mainBar // {
    modules-left = lib.remove "custom/launcher" mainBar.modules-left;
    modules-right = lib.remove "custom/power" mainBar.modules-right;
  };

  # Deliberately minimal
  minimalBar = {
    layer = "top";
    include = [ "~/.config/waybar/modules.json" ];
    modules-left = [
      "cpu"
      "memory"
      "disk"
    ]
    ++ lib.optional hasHomePartition "disk#home";
    modules-center = [ "hyprland/workspaces" ];
    modules-right = [
      "network"
      "pulseaudio"
      "clock"
    ];
  };

  bars =
    {
      GLaDOS = [
        (mainBar // { output = "HDMI-A-1"; })
        (secondaryBar // { output = "DP-3"; })
        (minimalBar // { output = "DP-1"; })
      ];
    }
    .${hostName} or [ mainBar ];

in
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

  # Bar layout
  home.file.".config/waybar/config.jsonc".text = builtins.toJSON bars;

  # Modules
  home.file.".config/waybar/modules.json".source = ./modules.json;

  # Styling
  home.file.".config/waybar/style.css".source = ./style.css;

  # Copy scripts
  home.file.".config/waybar/scripts/check_flake_updates.sh".source = ./check_flake_updates.sh;
  home.file.".config/waybar/scripts/claude_usage.sh".source = ./claude_usage.sh;
  home.file.".config/waybar/scripts/tailscale.sh".source = ./tailscale.sh;

}
