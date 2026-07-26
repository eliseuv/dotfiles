{ ... }:
{

  networking.networkmanager.enable = true;

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
