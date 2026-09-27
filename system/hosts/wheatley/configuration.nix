{ config, pkgs, ... }:
{

  imports = [

    # Hardware
    ./hardware.nix

    # Profiles
    ../../profiles/base.nix

    # Services
    ./firewall.nix
    ./ledger-web.nix
    ./ledger-deploy.nix
    ./nas.nix
    ./media-server.nix
    ./dashboard.nix
    ./minecraft.nix

    # Tailscale
    ../../extra/tailscale.nix

    # Secrets
    ../../extra/sops.nix

  ];

  # Hostname
  networking.hostName = "wheatley";
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 3000 3001 ]; # ttyd, ledger-web
  networking.firewall.lan.allowedTCPPorts = [ 5173 5174 1111 ]; # vite (+fallback), zola

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
