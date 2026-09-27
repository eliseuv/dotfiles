# Firewall policy, in three tiers, each declared next to its service:
#  - LAN (networking.firewall.lan below): every service.
#  - Tailnet (networking.firewall.interfaces.tailscale0): the subset meant for
#    remote use. These are open on the LAN too, without re-listing them.
#  - Everyone (networking.firewall.allowed*Ports): only what has to be public,
#    i.e. the torrent port. No openFirewall anywhere, since that means this.
#
# The LAN is matched on source address rather than interface: the LAN NIC
# also carries globally routable IPv6 addresses, so an interface rule would
# admit the internet whenever the router passes inbound IPv6. The LAN's
# global IPv6 prefix is ISP-delegated and can change, so apart from
# link-local (mDNS), LAN clients reach services over IPv4.
{ config, lib, ... }:
let
  cfg = config.networking.firewall.lan;
  tailnet = config.networking.firewall.interfaces.tailscale0 or { };

  sources = {
    iptables = "192.168.0.0/24";
    ip6tables = "fe80::/10";
  };
  accept =
    protocol: ports:
    lib.concatLists (
      lib.mapAttrsToList (
        tool: source:
        map (port: "${tool} -A nixos-fw -s ${source} -p ${protocol} --dport ${toString port} -j nixos-fw-accept") (
          lib.unique ports
        )
      ) sources
    );

  portsOption =
    protocol:
    lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = "${protocol} ports open to the LAN only.";
    };
in
{

  options.networking.firewall.lan = {
    allowedTCPPorts = portsOption "TCP";
    allowedUDPPorts = portsOption "UDP";
  };

  config = {
    networking.firewall = {
      extraCommands = lib.concatLines (
        accept "tcp" (cfg.allowedTCPPorts ++ tailnet.allowedTCPPorts or [ ])
        ++ accept "udp" (cfg.allowedUDPPorts ++ tailnet.allowedUDPPorts or [ ])
      );
      # Avahi publishes this host's IPv6 addresses too, and clients that try
      # those first must be refused quickly to fall back to IPv4; a silent
      # drop leaves ssh hanging until its connect timeout.
      rejectPackets = true;

      interfaces.tailscale0.allowedTCPPorts = [ 22 ];
      lan.allowedUDPPorts = [ 5353 ];
    };
    services.openssh.openFirewall = false;
    services.avahi.openFirewall = false;
  };

}
