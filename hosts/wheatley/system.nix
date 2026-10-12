{ config, ... }:
let
  inherit (config.homelab.network) tailnet;
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
    ./services/netdata.nix
  ];

  # Keep the MAC and the DHCP client-id from drifting (randomization,
  # DUID-based ids), so the router keeps handing out the same lease.
  networking.networkmanager = {
    wifi.macAddress = "permanent";
    ethernet.macAddress = "permanent";
    settings.connection."ipv4.dhcp-client-id" = "mac";
  };

  homelab.network.nasAddress = config.my.services.nas.address;

  # Here rather than in the tailscale module, which hosts without the
  # homelab registry share.
  homelab.services.tailscale.dashboard = {
    name = "Tailscale";
    group = "Tools";
    order = 3;
    description = "Tailnet admin console";
    icon = "tailscale.png";
    href = "https://login.tailscale.com/admin/machines";
  };

  # Terminal, switch, restart and on/off buttons for GLaDOS, which has no
  # services of its own here; wheatley is the always-on LAN host that can send
  # her the wake packet.
  # The icon is a placeholder the dashboard theme draws over with her head.
  homelab.services.glados.dashboard = {
    name = "GLaDOS";
    group = "Desktops";
    order = 0;
    icon = "mdi-robot-industrial";
    link = false;
    wake = "GLaDOS";
    poweroff = true;
    terminal = "/glados/terminal/";
    switch = "GLaDOS";
    reboot = "GLaDOS";
    tailscale = "GLaDOS";
    page = "GLaDOS";
    # Mirrors her devPorts (hosts/GLaDOS/system.nix), which open them.
    portsHost = "GLaDOS";
    ports = {
      HTTP = 8080;
      Zola = 1111;
      Vite = 5173;
    };
  };
  # For the dashboard's power-off (over mDNS) and switch (over the tailnet),
  # which SSH to her with strict host key checking.
  programs.ssh.knownHosts."glados.local" = {
    extraHostNames = [ "glados.${config.homelab.network.tailnetDomain}" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB/zYzxZZv+cAVbffNG59reLWlJeKjA7g92eAi0VVdS9";
  };

  # Wake, restart, on/off, Tailscale, terminal and ports buttons for the Pop!_OS
  # desktop, which isn't a host here: its remote-control login, forced
  # command, ttyd unit and firewall rule are set up by hand to mirror
  # services/remote-control.nix, services/ttyd.nix and GLaDOS's firewall,
  # as docs/pop-os.md records. No `address`, so like GLaDOS it's reached over
  # the tailnet, then mDNS.
  homelab.services.pop-os.dashboard = {
    name = "pop-os";
    group = "Desktops";
    order = 2;
    icon = "/icons/pop-os.svg";
    link = false;
    wake = "pop-os";
    poweroff = true;
    reboot = "pop-os";
    tailscale = "pop-os";
    terminal = "/pop-os/terminal/";
    # The same dev ports as GLaDOS's, opened by hand in ufw (docs/pop-os.md).
    portsHost = "pop-os";
    ports = {
      HTTP = 8080;
      Zola = 1111;
      Vite = 5173;
    };
  };
  programs.ssh.knownHosts."pop-os.local" = {
    extraHostNames = [ "pop-os.${config.homelab.network.tailnetDomain}" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBPufcEsAPYzlxegM5uUoNAnHmCKuGA3i2XqcXwZrpgN";
  };
  # Its ttyd, proxied by tailnet address for the same reasons as GLaDOS's
  # below; only wheatley may reach it (ufw there).
  services.nginx.virtualHosts.dashboard.locations."/pop-os/terminal/" = {
    proxyPass = "http://${tailnet.pop-os}:3000";
    proxyWebsockets = true;
    extraConfig = ''
      proxy_read_timeout 1d;
    '';
  };

  # Her ttyd (my.services.ttyd in hosts/GLaDOS), proxied so it's reachable
  # wherever the dashboard is, tailnet included; her firewall only admits
  # wheatley, over the tailnet. By her tailnet address rather than a name:
  # nginx resolves upstream names once at startup, and fails to start if she's
  # asleep (.local) or tailscaled isn't up yet (MagicDNS). Long read
  # timeout so an idle terminal's websocket isn't cut after nginx's default 60s.
  services.nginx.virtualHosts.dashboard.locations."/glados/terminal/" = {
    proxyPass = "http://${tailnet.GLaDOS}:3000";
    proxyWebsockets = true;
    extraConfig = ''
      proxy_read_timeout 1d;
    '';
  };

  # Terminal, switch and restart buttons for wheatley himself; no on/off, as
  # nothing here could turn him back on. First in Headless servers, followed
  # by Companion Cube.
  # The icon is a placeholder the dashboard theme draws over with his core.
  homelab.services.wheatley.dashboard = {
    name = "Wheatley";
    group = "Headless servers";
    order = 0;
    icon = "mdi-server";
    link = false;
    reboot = "wheatley";
    switch = "wheatley";
    terminal = "/wheatley/terminal/";
    page = "wheatley";
    ports = with config.homelab.services; {
      Vite = vite.port;
      "Vite (fallback)" = vite-fallback.port;
      Zola = zola.port;
    };
  };

  # The same buttons as GLaDOS's for chell, the shared family workstation
  # (hosts/chell). Dual-booted with pop-os, whose tile wakes the same machine.
  homelab.services.chell.dashboard = {
    name = "Chell";
    group = "Desktops";
    order = 1;
    icon = "/icons/chell.svg";
    link = false;
    wake = "chell";
    poweroff = true;
    terminal = "/chell/terminal/";
    switch = "chell";
    reboot = "chell";
    tailscale = "chell";
    page = "chell";
    # Mirrors her devPorts (hosts/chell/system.nix), which open them.
    portsHost = "chell";
    ports = {
      HTTP = 8080;
      Zola = 1111;
      Vite = 5173;
    };
  };
  # Her ttyd, proxied by tailnet address and firewalled as GLaDOS's
  services.nginx.virtualHosts.dashboard.locations."/chell/terminal/" = {
    proxyPass = "http://${tailnet.chell}:3000";
    proxyWebsockets = true;
    extraConfig = ''
      proxy_read_timeout 1d;
    '';
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
