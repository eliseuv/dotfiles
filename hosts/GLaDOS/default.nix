# Main workstation
{ ... }:
{

  my.desktop = {
    hyprland.enable = true;
    gnome.enable = true;
    gdmMonitors = ./monitors.xml;
    waybar.homeDisk = true;
    monitors = [
      {
        output = "DP-1";
        mode = "1920x1080@60.0";
        position = "0x1080";
        transform = 1;
        bar = "minimal";
      }
      {
        output = "DP-3";
        mode = "2560x1080@74.99";
        position = "440x0";
        bar = "secondary";
      }
      {
        output = "HDMI-A-1";
        mode = "1920x1080@239.76";
        position = "1080x1080";
        bar = "main";
      }
    ];
  };

  my.hardware.nvidia.enable = true;

  my.services = {
    tailscale.enable = true;
    nas.enable = true;
    containers.enable = true;
    virtualisation.enable = true;
    remotePowerOff.enable = true;
    dotfilesSwitch.enable = true;
    # Served through wheatley's dashboard nginx, which proxies this subpath to
    # her (hosts/wheatley/system.nix).
    ttyd = {
      enable = true;
      basePath = "/glados/terminal";
    };
  };

  my.gaming.enable = true;

  my.secrets = {
    system.enable = true;
    user.enable = true;
  };

  my.home = {
    apps.enable = true;
    notes.enable = true;
    cloudSync.enable = true;
    remoteAccess.enable = true;
  };

}
