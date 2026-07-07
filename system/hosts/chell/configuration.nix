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
  networking.hostName = "chell";

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
