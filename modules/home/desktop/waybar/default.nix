{
  config,
  lib,
  pkgs,
  ...
}:
let

  # One layout shared by every host so bars can't drift apart; hosts only
  # differ in hardware-specific modules and in their outputs.
  # One native disk module per configured mount: "disk#0", "disk#1", ...
  diskModules = lib.listToAttrs (
    lib.imap0 (index: disk: {
      name = "disk#${toString index}";
      value = {
        inherit (disk) path;
        format = "${disk.icon}  {percentage_used}%";
      };
    }) config.my.desktop.waybar.disks
  );
  diskNames = lib.attrNames diskModules;
  hasBluetooth = config.my.hardware.bluetooth.enable;

  mainBar = diskModules // {
    layer = "top";
    include = [ "~/.config/waybar/modules.json" ];
    modules-left = [
      "custom/launcher"
      "cpu"
      "memory"
    ]
    ++ diskNames
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
      "custom/wheatley"
      "custom/bitwarden"
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
  minimalBar = diskModules // {
    layer = "top";
    include = [ "~/.config/waybar/modules.json" ];
    modules-left = [
      "cpu"
      "memory"
    ]
    ++ diskNames;
    modules-center = [ "hyprland/workspaces" ];
    modules-right = [
      "network"
      "pulseaudio"
      "clock"
    ];
  };

  layouts = {
    main = mainBar;
    secondary = secondaryBar;
    minimal = minimalBar;
  };
  rank =
    bar:
    lib.lists.findFirstIndex (layout: layout == bar) null [
      "main"
      "secondary"
      "minimal"
    ];

  # One bar per monitor that names a layout, primary first; with none named,
  # a single main bar on whatever output waybar picks
  barMonitors = lib.sort (a: b: rank a.bar < rank b.bar) (
    lib.filter (monitor: monitor.bar != null) config.my.desktop.monitors
  );
  bars =
    if barMonitors == [ ] then
      [ mainBar ]
    else
      map (monitor: layouts.${monitor.bar} // { inherit (monitor) output; }) barMonitors;

in
{

  config = lib.mkIf config.my.desktop.hyprland.enable {

    programs.waybar = {
      enable = true;
      # Started with the graphical session (UWSM reaches graphical-session.target)
      # rather than from Hyprland's autostart
      systemd.enable = true;
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
    home.file.".config/waybar/scripts/wheatley.sh".source = ./wheatley.sh;
    home.file.".config/waybar/scripts/bitwarden.sh".source = ./bitwarden.sh;

  };

}
