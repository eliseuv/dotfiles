{ ... }:
let
  plutoForward = {
    bind.port = 1234;
    host.address = "127.0.0.1";
    host.port = 1234;
  };
in
{

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      # Default settings for all hosts
      "*" = {
        compression = true;
        addKeysToAgent = "yes";
        forwardAgent = true;
        serverAliveInterval = 240;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
      };
      # Alpine Linux VM
      "alpine-vm" = {
        hostname = "alpine-vm.local";
        user = "root";
      };
      # Dani Windows
      "dani-win" = {
        hostname = "DESKTOP-8D6IO5L.local";
        user = "danis";
      };
      # Dani WSL
      "dani-wsl" = {
        hostname = "DESKTOP-8D6IO5L.local";
        port = 2222;
      };
      # Personal computer at IF-UFRGS
      "if-ufrgs" = {
        hostname = "143.54.45.50";
        user = "evf";
        proxyJump = "alpine-vm";
      };
      # LIEF
      "lief" = {
        hostname = "lief.if.ufrgs.br";
        user = "eliseuvf";
        proxyJump = "alpine-vm";
      };
      # Ada Lovelace cluster
      "lovelace" = {
        hostname = "lovelace.if.ufrgs.br";
        user = "eliseuvf";
        proxyJump = "alpine-vm";
      };
      # Ada Lovelace cluster
      "ada" = {
        hostname = "lovelace.if.ufrgs.br";
        user = "eliseuvf";
        proxyJump = "alpine-vm";
      };
      # Wheatley (tailscale jump host)
      "wheatley" = {
        hostname = "wheatley";
        user = "evf";
      };
      # GLaDOS, reached via wheatley since it is not on the tailnet
      "glados" = {
        hostname = "GLaDOS.local";
        user = "evf";
        proxyJump = "wheatley";
      };
      # GLaDOS directly, when on its LAN without tailscale
      "glados-lan" = {
        hostname = "GLaDOS.local";
        user = "evf";
      };
      # Pluto tunnels (`ssh -N glados-pluto`). Separate hosts so a regular
      # `ssh glados` doesn't try to bind the port. Same local port as remote
      # so the URL Pluto prints, secret included, opens as-is.
      "glados-pluto" = {
        hostname = "GLaDOS.local";
        user = "evf";
        proxyJump = "wheatley";
        LocalForward = [ plutoForward ];
      };
      "glados-lan-pluto" = {
        hostname = "GLaDOS.local";
        user = "evf";
        LocalForward = [ plutoForward ];
      };
    };
  };

}
