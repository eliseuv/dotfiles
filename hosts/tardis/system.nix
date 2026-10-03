{ config, pkgs, ... }:
{

  imports = [

    # Profiles
    ../../system/profiles/base.nix
    ../../system/profiles/desktop.nix

    # Bluetooth
    ../../system/hardware/bluetooth.nix

    # Display manager
    ../../system/desktop/display-manager/gdm/default.nix

    # Window manager
    ../../system/desktop/window-manager/hyprland.nix
    ../../system/desktop/window-manager/gnome.nix

    # Boot graphics
    ../../system/extra/plymouth.nix

    # Tailscale
    ../../system/extra/tailscale.nix

    # NAS home folder
    ../../system/extra/companion-cube.nix

  ];

  # Also mount the NAS over the tailnet, for use away from home
  companionCube.tailnetAddress = "100.109.162.27";

  # Select default session for Display Manager
  services.displayManager.defaultSession = "hyprland-uwsm";

  # Disk encryption
  boot.initrd.luks.devices."luks-2ac9cd27-6ff4-4407-9808-c63a5251c44c".device =
    "/dev/disk/by-uuid/2ac9cd27-6ff4-4407-9808-c63a5251c44c";

  environment.systemPackages = with pkgs; [

    # Screen brightness control
    brightnessctl

  ];

}
