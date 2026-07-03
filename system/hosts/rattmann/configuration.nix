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
    ../../desktop/display-manager/lightdm.nix

    # Window manager
    ../../desktop/window-manager/i3.nix

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
  networking.hostName = "rattmann";

  # Allow user to install system-wide packages
  nix.settings.trusted-users = [ "evf" ];

  # Select default session for Display Manager
  services.displayManager.defaultSession = "none+i3";

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  environment.systemPackages = with pkgs; [

    # Screen brightness control
    brightnessctl

  ];

  system.stateVersion = "24.11";

}
