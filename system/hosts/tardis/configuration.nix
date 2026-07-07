{ config, pkgs, ... }:
{

  imports = [

    # Hardware
    ./hardware.nix

    # Profiles
    ../../profiles/base.nix
    ../../profiles/desktop.nix

    # Bluetooth
    ../../hardware/bluetooth.nix

    # Display manager
    ../../desktop/display-manager/gdm/default.nix

    # Window manager
    ../../desktop/window-manager/hyprland.nix
    ../../desktop/window-manager/gnome.nix

    # Boot graphics
    ../../extra/plymouth.nix

    # Tailscale
    ../../extra/tailscale.nix

  ];

  # Hostname
  networking.hostName = "tardis";

  # Select default session for Display Manager
  services.displayManager.defaultSession = "hyprland";

  # Disk encryption
  boot.initrd.luks.devices."luks-2ac9cd27-6ff4-4407-9808-c63a5251c44c".device =
    "/dev/disk/by-uuid/2ac9cd27-6ff4-4407-9808-c63a5251c44c";

  environment.systemPackages = with pkgs; [

    # Screen brightness control
    brightnessctl

  ];

  system.stateVersion = "24.11";

}
