{ config, ... }:
{

  imports = [
    ./nas.nix
    ./services/ledger/web.nix
    ./services/ledger/deploy.nix
    ./services/media
    ./services/minecraft.nix
    ./services/dev.nix
    ./services/ttyd.nix
  ];

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
    nasAddress = config.my.services.nas.address;
    tailnetDomain = "taild628c9.ts.net";
    tailnetAddress = "100.97.1.97";
  };

  # Here rather than in the tailscale module, which hosts without the
  # homelab registry share.
  homelab.services.tailscale.dashboard = {
    name = "Tailscale";
    group = "Hosts";
    order = 2;
    description = "Tailnet admin console";
    icon = "tailscale.png";
    href = "https://login.tailscale.com/admin/machines";
  };

  # Wake and power-off buttons for GLaDOS, which has no services of its own
  # here; wheatley is the always-on LAN host that can send her the packet.
  # The icon is a placeholder the dashboard theme draws over with her head.
  homelab.services.glados.dashboard = {
    name = "GLaDOS";
    group = "Hosts";
    order = 0;
    description = "Genetic Lifeform and Disk Operating System";
    icon = "mdi-robot-industrial";
    link = false;
    wake = "GLaDOS";
    poweroff = true;
  };
  # For the dashboard's power-off, which SSHes to her with strict host key
  # checking.
  programs.ssh.knownHosts."glados.local".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB/zYzxZZv+cAVbffNG59reLWlJeKjA7g92eAi0VVdS9";

  # Her ttyd (my.services.ttyd in hosts/GLaDOS), proxied so it's reachable
  # wherever the dashboard is, tailnet included; her firewall only admits
  # wheatley. By address rather than GLaDOS.local: nginx resolves upstream
  # names once at startup, and fails to start if she's asleep then. Long read
  # timeout so an idle terminal's websocket isn't cut after nginx's default 60s.
  services.nginx.virtualHosts.dashboard.locations."/glados/terminal/" = {
    proxyPass = "http://192.168.0.51:3000";
    proxyWebsockets = true;
    extraConfig = ''
      proxy_read_timeout 1d;
    '';
  };

  # Remove bootloader timeout
  boot.loader.timeout = 0;

  # Do not hibernate on lid close
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

}
