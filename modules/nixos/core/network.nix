{ config, lib, ... }:
{

  networking.networkmanager.enable = true;

  # Arm Wake-on-LAN on hosts listed as `wake` targets. Through NetworkManager
  # rather than networking.interfaces.<name>.wakeOnLan, which would hardcode
  # the interface name. 64 is NM's magic-packet flag; this global default
  # applies to every wired connection, which on these single-NIC hosts is the
  # one that matters.
  networking.networkmanager.settings.connection."ethernet.wake-on-lan" = lib.mkIf (
    config.my.wakeOnLan.hosts ? ${config.my.host.name}
  ) 64;

  # networking.nameservers = [ "130.161.158.4" "130.161.33.17" ];
  networking.nameservers = [
    "8.8.8.8"
    "1.1.1.1"
  ];

  networking.firewall.allowedTCPPorts = [ 5173 ];

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Avahi
  services.avahi = {
    enable = true;

    # mDNS NSS plug-in for IPv4 allows applications to resolve names in the .local domain by transparently querying the Avahi daemon
    nssmdns4 = true;

    publish = {
      enable = true;
      addresses = true;
    };
  };

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
