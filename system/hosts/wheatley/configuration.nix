{ config, pkgs, ... }:
{

  imports = [

    # Hardware
    ./hardware.nix

    # Bootloader
    ../../hardware/bootloader.nix

    # Network
    ../../hardware/network.nix

    # Environment
    ../../environment/default.nix

  ];

  # Flakes support
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Hostname
  networking.hostName = "wheatley";

  # Allow user to install system-wide packages
  nix.settings.trusted-users = [ "evf" ];

  # Do not hibernate on lid close
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
  };



  # State version
  system.stateVersion = "24.11";

}
