{ pkgs, ... }:
{

  # GNOME Display Manager (GDM)
  services.displayManager.gdm = {
    enable = true;
    autoSuspend = false;
  };

  # Copy monitor positions from GNOME desktop to GDM config
  systemd.services.copyGdmMonitorsXml = {
    description = "Copy monitors.xml to GDM config";
    after = [
      "network.target"
      "systemd-user-sessions.service"
      "display-manager.service"
    ];

    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo \"Running copyGdmMonitorsXml service\" && mkdir -p /run/gdm/.config && echo \"Created /run/gdm/.config directory\" && [ \"/home/evf/.config/monitors.xml\" -ef \"/run/gdm/.config/monitors.xml\" ] || cp /home/evf/.config/monitors.xml /run/gdm/.config/monitors.xml && echo \"Copied monitors.xml to /run/gdm/.config/monitors.xml\" && chown gdm:gdm /run/gdm/.config/monitors.xml && echo \"Changed ownership of monitors.xml to gdm\"'";
      Type = "oneshot";
    };

    wantedBy = [ "multi-user.target" ];
  };

}
