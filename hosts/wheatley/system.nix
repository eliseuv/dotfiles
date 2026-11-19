{ config, ... }:
let
  inherit (config.homelab.network) ports;
in
{

  imports = [
    ./nas.nix
    ./services/ledger/web.nix
    ./services/ledger/deploy.nix
    ./services/media
    ./services/minecraft.nix
    ./services/dev.nix
    ./services/ttyd.nix
    ./services/pluto.nix
    ./services/drive.nix
    ./services/beszel.nix
    ./services/aven.nix
  ];

  # Keep the MAC and the DHCP client-id from drifting (randomization,
  # DUID-based ids), so the router keeps handing out the same lease.
  networking.networkmanager = {
    wifi.macAddress = "permanent";
    ethernet.macAddress = "permanent";
    settings.connection."ipv4.dhcp-client-id" = "mac";
  };

  homelab.network.nasAddress = config.my.services.nas.address;

  # GLaDOS, which has no services of its own here; wheatley is the always-on
  # LAN host that can send her the wake packet. Her buttons and terminal
  # follow from her own my.services (hosts/GLaDOS).
  # The icon is a placeholder the dashboard theme draws over with her head.
  homelab.services.glados.dashboard = {
    name = "GLaDOS";
    group = "Desktops";
    order = 0;
    icon = "mdi-robot-industrial";
    link = false;
    host = "GLaDOS";
    ports = ports.GLaDOS.dev;
  };
  # For the dashboard's power-off (over mDNS) and switch (over the tailnet),
  # which SSH to her with strict host key checking.
  programs.ssh.knownHosts."glados.local" = {
    extraHostNames = [ "glados.${config.homelab.network.tailnetDomain}" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB/zYzxZZv+cAVbffNG59reLWlJeKjA7g92eAi0VVdS9";
  };

  # Wheatley himself: terminal, switch and restart, no on/off, as nothing
  # here could turn him back on. First in Servers, followed by Companion Cube.
  # The icon is a placeholder the dashboard theme draws over with his core.
  homelab.services.wheatley.dashboard = {
    name = "Wheatley";
    group = "Servers";
    order = 0;
    icon = "mdi-server";
    link = false;
    host = "wheatley";
    ports = ports.wheatley.dev;
  };

  # chell, the shared family workstation (hosts/chell), as GLaDOS.
  homelab.services.chell.dashboard = {
    name = "Chell";
    group = "Desktops";
    order = 1;
    icon = "/icons/chell.svg";
    link = false;
    host = "chell";
    ports = ports.chell.dev;
  };
  programs.ssh.knownHosts."chell.local" = {
    extraHostNames = [ "chell.${config.homelab.network.tailnetDomain}" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOJ7vohSNKj77Q/2SrcKtNsWgFa/FCnx++p8rL/W+WYk";
  };

  # Remove bootloader timeout
  boot.loader.timeout = 0;

  # Do not hibernate on lid close
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

}
