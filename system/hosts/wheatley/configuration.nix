{ config, pkgs, ... }:
{

  imports = [

    # Hardware
    ./hardware.nix

    # Profiles
    ../../profiles/base.nix

    # Services
    ./ledger-web.nix

  ];

  # Hostname
  networking.hostName = "wheatley";
  networking.firewall.allowedTCPPorts = [ 3000 3001 5173 5174 1111 ]; # ttyd, ledger-web, vite (+fallback), zola

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
