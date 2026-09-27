{ config, pkgs, ... }:
{

  imports = [

    # Hardware
    ./hardware.nix

    # Profiles
    ../../profiles/base.nix

    # Services
    ./homelab.nix
    ./firewall.nix
    ./nas.nix
    ./services/ledger/web.nix
    ./services/ledger/deploy.nix
    ./services/media
    ./services/dashboard
    ./services/minecraft.nix
    ./services/dev.nix

    # Tailscale
    ../../extra/tailscale.nix

    # Secrets
    ../../extra/sops.nix

  ];

  # Host secrets; modules declare the ones they use.
  sops.defaultSopsFile = ../../../secrets/wheatley.yaml;

  # Hostname
  networking.hostName = "wheatley";

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
