{ config, pkgs, ... }:
{

  imports = [

    # Hardware
    ./hardware.nix

    # Profiles
    ../../profiles/base.nix

  ];

  # Hostname
  networking.hostName = "wheatley";
  networking.firewall.allowedTCPPorts = [ 3000 ]; # ttyd

  # Remove bootloader timeout
  boot.loader.timeout = 0;

  # Do not hibernate on lid close
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  # State version
  system.stateVersion = "24.11";

}
