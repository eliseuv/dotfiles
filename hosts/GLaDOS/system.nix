{ config, pkgs, ... }:
{

  imports = [

    # Profiles
    ../../system/profiles/base.nix
    ../../system/profiles/desktop.nix

    # Display manager
    ../../system/desktop/display-manager/gdm/default.nix

    # Window manager
    ../../system/desktop/window-manager/hyprland.nix
    ../../system/desktop/window-manager/gnome.nix

    # NVidia graphics
    ../../system/hardware/nvidia.nix

    # Virtualization
    ../../system/extra/virtual-machines.nix

    # Containers
    ../../system/extra/docker.nix
    ../../system/extra/podman.nix

    # Games
    ../../system/extra/steam.nix

    # Tailscale
    ../../system/extra/tailscale.nix

    # NAS home folder
    ../../system/extra/companion-cube.nix

  ];

  # Select default session for Display Manager
  services.displayManager.defaultSession = "hyprland-uwsm";

  # Mount disks
  fileSystems = {

    "/run/media/evf/Storage" = {
      device = "/dev/disk/by-uuid/2C22035322032186";
      fsType = "ntfs";
      options = [ "nofail" ];
    };

    "/run/media/evf/Research" = {
      device = "/dev/disk/by-uuid/e29cc859-5e69-4dbc-aefa-445ee3da919f";
      fsType = "ext4";
      options = [ "nofail" ];
    };

  };

  # Configure GDM monitors
  environment.etc."xdg/monitors.xml" = {
    source = ./monitors.xml;
    mode = "0644";
  };

}
