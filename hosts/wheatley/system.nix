{ config, lib, ... }:
let
  # rattmann's tailnet address, for his terminal. TODO: fill in once he has
  # joined (`tailscale up`); while null he has no terminal button or proxy.
  rattmannAddress = null;
  # chell's, likewise. TODO: fill in after `tailscale up --operator=evf` on chell.
  chellAddress = null;
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

  # The router hands out no fixed addresses, so hosts are reached by mDNS name
  # on the LAN and by tailnet address elsewhere.
  homelab.network = {
    lanSubnet = "192.168.0.0/24";
    nasAddress = config.my.services.nas.address;
    tailnetDomain = "taild628c9.ts.net";
    tailnetAddress = "100.97.1.97";
  };

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
    group = "Hosts";
    order = 2;
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
    group = "Hosts";
    order = 3;
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
    proxyPass = "http://100.68.2.108:3000";
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
    proxyPass = "http://100.110.170.42:3000";
    proxyWebsockets = true;
    extraConfig = ''
      proxy_read_timeout 1d;
    '';
  };

  # Terminal, switch and restart buttons for wheatley himself; no on/off, as
  # nothing here could turn him back on. First in Hosts, followed by the
  # Companion Cube and GLaDOS, so the Aperture machines fill the first row.
  # The icon is a placeholder the dashboard theme draws over with his core.
  homelab.services.wheatley.dashboard = {
    name = "Wheatley";
    group = "Hosts";
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

  # Wake, switch and restart buttons for rattmann, the old laptop that serves
  # as this dashboard's kiosk (hosts/rattmann). No on/off: it's a screen
  # someone is looking at, switched off by hand and woken from here.
  homelab.services.rattmann.dashboard = {
    name = "Rattmann";
    group = "Hosts";
    order = 4;
    icon = "mdi-laptop";
    link = false;
    wake = "rattmann";
    reboot = "rattmann";
    switch = "rattmann";
    terminal = lib.mkIf (rattmannAddress != null) "/rattmann/terminal/";
  };
  # His ttyd (my.services.ttyd in hosts/rattmann), proxied by tailnet address
  # for the same reasons as GLaDOS's; his firewall only admits wheatley. Port
  # is his my.services.ttyd.port.
  services.nginx.virtualHosts.dashboard.locations."/rattmann/terminal/" =
    lib.mkIf (rattmannAddress != null)
      {
        proxyPass = "http://${rattmannAddress}:3000";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_read_timeout 1d;
        '';
      };
  programs.ssh.knownHosts."rattmann.local" = {
    extraHostNames = [ "rattmann.${config.homelab.network.tailnetDomain}" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMSS/e/drunmk5UHJ5mplGg0hIKznGeZWL/eL7QRlYKU";
  };

  # Switch and tailscale buttons for chell, the shared family workstation
  # (hosts/chell); no power buttons, as someone else may be using it.
  homelab.services.chell.dashboard = {
    name = "Chell";
    group = "Hosts";
    order = 5;
    icon = "mdi-desktop-tower";
    link = false;
    switch = "chell";
    tailscale = "chell";
    page = "chell";
    terminal = lib.mkIf (chellAddress != null) "/chell/terminal/";
  };
  # Her ttyd, proxied and firewalled as rattmann's
  services.nginx.virtualHosts.dashboard.locations."/chell/terminal/" =
    lib.mkIf (chellAddress != null)
      {
        proxyPass = "http://${chellAddress}:3000";
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
