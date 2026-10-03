{ config, pkgs, ... }:
{

  imports = [

    # Profiles
    ../../system/profiles/base.nix
    ../../system/profiles/desktop.nix

    # Bluetooth
    ../../system/hardware/bluetooth.nix

    # Display manager
    ../../system/desktop/display-manager/lightdm.nix

    # Window manager
    ../../system/desktop/window-manager/i3.nix

    # Boot graphics
    ../../system/extra/plymouth.nix

    # Tailscale
    ../../system/extra/tailscale.nix

  ];

  # Select default session for Display Manager
  services.displayManager.defaultSession = "none+i3";

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  environment.systemPackages = with pkgs; [

    # Screen brightness control
    brightnessctl

  ];

}
