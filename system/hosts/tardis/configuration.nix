{
  config,
  pkgs,
  lib,
  ...
}:
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

    # Bluetooth
    ../../hardware/bluetooth.nix

    #Environment
    ../../environment/default.nix

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

  # Flakes support
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Hostname
  networking.hostName = "tardis";

  # Allow user to install system-wide packages
  nix.settings.trusted-users = [ "evf" ];

  # Select default session for Display Manager
  services.displayManager.defaultSession = "hyprland";

  # Disk encryption
  boot.initrd.luks.devices."luks-2ac9cd27-6ff4-4407-9808-c63a5251c44c".device =
    "/dev/disk/by-uuid/2ac9cd27-6ff4-4407-9808-c63a5251c44c";

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  environment.systemPackages = with pkgs; [

    # Screen brightness control
    brightnessctl

  ];

  system.stateVersion = "24.11";

}
