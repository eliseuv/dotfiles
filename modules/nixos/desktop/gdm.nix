{ config, lib, ... }:
{

  config = lib.mkIf (config.my.desktop.enable && config.my.desktop.displayManager == "gdm") {

    # GNOME Display Manager (GDM)
    services.displayManager.gdm = {
      enable = true;
      autoSuspend = false;
    };

    environment.etc."xdg/monitors.xml" = lib.mkIf (config.my.desktop.gdmMonitors != null) {
      source = config.my.desktop.gdmMonitors;
      mode = "0644";
    };

  };

}
