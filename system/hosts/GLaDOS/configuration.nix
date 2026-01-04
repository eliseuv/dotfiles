{ config, pkgs, ... }:
{

  imports = [

    # Hardware
    ./hardware.nix

    # Bootloader
    ../../hardware/bootloader.nix

    # Disks
    ../../hardware/disks.nix

    # Audio
    ../../hardware/audio.nix

    # Network
    ../../hardware/network.nix

    # Keyboard
    ../../hardware/keyboard.nix

    # Printing
    ../../hardware/printing.nix

    # Environment
    ../../environment/default.nix

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

  # Flakes support
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Hostname
  networking.hostName = "GLaDOS";

  # Allow user to install system-wide packages
  nix.settings.trusted-users = [ "evf" ];

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

  system.stateVersion = "24.11";

}
