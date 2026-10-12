# Shared family workstation
{ ... }:
{

  my.host.users = [
    "evf"
    "dani"
  ];

  # The dotfiles repository is shared between users on this machine
  my.dotfiles = {
    path = "/etc/dotfiles";
    shared = true;
  };

  # evf's Hyprland as on GLaDOS; GNOME for dani (home-dani.nix) and for
  # anyone else without a saved choice at GDM.
  my.desktop = {
    hyprland.enable = true;
    gnome.enable = true;
    defaultSession = "gnome";
    userSessions.evf = "hyprland-uwsm";
    gdmMonitors = ./monitors.xml;
    # As in monitors.xml; GNOME's rotation `right` is Hyprland's transform 3
    monitors = [
      {
        output = "HDMI-A-1";
        mode = "1920x1080@60.0";
        position = "0x755";
        bar = "main";
      }
      {
        output = "DP-3";
        mode = "2560x1080@59.978";
        position = "1920x0";
        transform = 3;
        bar = "secondary";
      }
    ];
  };

  my.hardware.nvidia.enable = true;

  my.services = {
    tailscale = {
      enable = true;
      upAtBoot = true;
    };
    containers.enable = true;
    virtualisation.enable = true;
    dotfilesSwitch.enable = true;
    remoteTailscale.enable = true;
    # Served through wheatley's dashboard nginx, which proxies this subpath to
    # it (hosts/wheatley/system.nix).
    ttyd = {
      enable = true;
      basePath = "/chell/terminal";
    };
  };

  my.gaming.enable = true;

  my.home = {
    apps.enable = true;
    cloudSync.enable = true;
    remoteAccess.enable = true;
  };

}
