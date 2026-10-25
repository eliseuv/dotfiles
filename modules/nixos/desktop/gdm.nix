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

    # The greeter ignores /etc/xdg/monitors.xml (it picked the wrong primary
    # monitor on GLaDOS); the per-seat config dir is what mutter honours there.
    systemd.tmpfiles.rules = lib.mkIf (config.my.desktop.gdmMonitors != null) [
      "L+ /var/lib/gdm/seat0/config/monitors.xml - - - - ${config.my.desktop.gdmMonitors}"
    ];

  };

}
