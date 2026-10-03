{ config, pkgs, ... }:
{

  imports = [

    # Profiles
    ../../system/profiles/base.nix
    ../../system/profiles/desktop.nix

    # Display manager
    ../../system/desktop/display-manager/gdm/default.nix

    # Window manager
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

  ];

  # Select default session for Display Manager
  services.displayManager.defaultSession = "gnome";

  # Configure GDM monitors
  environment.etc."xdg/monitors.xml" = {
    source = ../../system/desktop/display-manager/gdm/monitors/chell.xml;
    mode = "0644";
  };

}
