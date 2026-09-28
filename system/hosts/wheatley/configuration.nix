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

    # NAS home folder
    ../../extra/companion-cube.nix

    # Secrets
    ../../extra/sops.nix

  ];

  # Host secrets; modules declare the ones they use.
  sops.defaultSopsFile = ../../../secrets/wheatley.yaml;

  # Hostname
  networking.hostName = "wheatley";

  # The router's reservation for lanAddress is keyed on the MAC, so keep both
  # the MAC and the DHCP client-id from drifting (randomization, DUID-based ids).
  networking.networkmanager = {
    wifi.macAddress = "permanent";
    ethernet.macAddress = "permanent";
    settings.connection."ipv4.dhcp-client-id" = "mac";
  };

  # The LAN and NAS addresses are DHCP reservations on the router.
  homelab.network = {
    lanSubnet = "192.168.0.0/24";
    lanAddress = "192.168.0.62";
    nasAddress = config.companionCube.address;
    tailnetDomain = "taild628c9.ts.net";
    tailnetAddress = "100.97.1.97";
  };

  # Here rather than in extra/tailscale.nix, which hosts without the
  # homelab registry share.
  homelab.services.tailscale.dashboard = {
    name = "Tailscale";
    group = "Tools";
    order = 4;
    description = "Tailnet admin console";
    icon = "tailscale.png";
    href = "https://login.tailscale.com/admin/machines";
  };

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
