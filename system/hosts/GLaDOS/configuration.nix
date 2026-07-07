{ config, pkgs, ... }:
{

  imports = [

    # Hardware
    ./hardware.nix

    # Profiles
    ../../profiles/base.nix
    ../../profiles/desktop.nix

    # Display manager
    ../../desktop/display-manager/gdm/default.nix

    # Window manager
    ../../desktop/window-manager/hyprland.nix
    ../../desktop/window-manager/gnome.nix

    # NVidia graphics
    ../../hardware/nvidia.nix

    # Virtualization
    ../../extra/virtual-machines.nix

    # Containers
    ../../extra/docker.nix
    ../../extra/podman.nix

    # Games
    ../../extra/steam.nix

  ];

  # Hostname
  networking.hostName = "GLaDOS";

  # Select default session for Display Manager
  services.displayManager.defaultSession = "hyprland";

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
    source = ../../desktop/display-manager/gdm/monitors/GLaDOS.xml;
    mode = "0644";
  };

  system.stateVersion = "24.11";

}
