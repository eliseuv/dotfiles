{ config, lib, ... }:
let
  cfg = config.my.desktop;
in
{

  options.my.desktop = {

    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.hyprland.enable || cfg.gnome.enable || cfg.i3.enable;
      defaultText = "whether any session is enabled";
      description = "Graphical environment: audio, printing, display manager.";
    };

    hyprland.enable = lib.mkEnableOption "the Hyprland session";
    gnome.enable = lib.mkEnableOption "the GNOME session";
    i3.enable = lib.mkEnableOption "the i3 session";

    defaultSession = lib.mkOption {
      type = lib.types.str;
      default =
        if cfg.hyprland.enable then
          "hyprland-uwsm"
        else if cfg.gnome.enable then
          "gnome"
        else
          "none+i3";
      defaultText = "the first enabled of Hyprland, GNOME, i3";
      description = "Session the display manager starts by default.";
    };

    displayManager = lib.mkOption {
      type = lib.types.enum [
        "gdm"
        "lightdm"
      ];
      default = "gdm";
    };

    gdmMonitors = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "GNOME monitors.xml for GDM's own monitor layout.";
    };

    bootSplash.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.my.host.type == "laptop";
      defaultText = ''my.host.type == "laptop"'';
      description = "Plymouth splash and a silent boot.";
    };

  };

}
