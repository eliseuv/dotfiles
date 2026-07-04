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
  networking.hostName = "chell";

  # Allow user to install system-wide packages
  nix.settings.trusted-users = [
    "evf"
    "dani"
  ];

  # Users
  users.users.dani = {
    isNormalUser = true;
    description = "dani";
    extraGroups = [
      "wheel"
      "networkmanager"
      "libvirtd"
      "dotfiles"
    ];
    packages = with pkgs; [ ];
  };

  # Select default session for Display Manager
  services.displayManager.defaultSession = "gnome";

  # Configure GDM monitors
  environment.etc."xdg/monitors.xml" = {
    source = ../../desktop/display-manager/gdm/monitors/chell.xml;
    mode = "0644";
  };

  system.stateVersion = "24.11";

}
