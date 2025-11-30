{ ... }:
{

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
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
        hostname = "localhost";
        port = 2222;
        proxyJump = "dani-win";
        extraOptions."StrictHostKeyChecking" = "no";
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
    };
  };

}
