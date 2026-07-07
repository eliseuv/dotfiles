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
    ../../desktop/display-manager/lightdm.nix

    # Window manager
    ../../desktop/window-manager/i3.nix

    # Boot graphics
    ../../extra/plymouth.nix

    # Tailscale
    ../../extra/tailscale.nix

  ];

  # Hostname
  networking.hostName = "rattmann";

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
