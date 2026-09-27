# Firewall policy, in three tiers, chosen per service with
# `homelab.services.<name>.expose` (homelab.nix) next to the service:
#  - "lan": every service.
#  - "tailnet": the subset meant for remote use. Open on the LAN too.
#  - "public": only what has to be, i.e. the torrent port. No openFirewall
#    anywhere, since that means this.
# Ports that aren't a service's primary one (discovery, mDNS) go straight into
# networking.firewall.lan below or interfaces.tailscale0.
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

  registered = lib.filter (service: service.port != null) (lib.attrValues config.homelab.services);
  tcpPorts = expose: map (service: service.port) (lib.filter (service: service.expose == expose) registered);
  udpPorts = expose: map (service: service.port) (lib.filter (service: service.expose == expose && service.udp) registered);

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

      lan.allowedTCPPorts = tcpPorts "lan";
      lan.allowedUDPPorts = udpPorts "lan" ++ [ 5353 ]; # mDNS
      interfaces.tailscale0.allowedTCPPorts = tcpPorts "tailnet";
      interfaces.tailscale0.allowedUDPPorts = udpPorts "tailnet";
      # Forced so it also drops the 5173 (vite) that the shared
      # system/hardware/network.nix opens to everyone; wheatley keeps that one
      # LAN-only (services/dev.nix).
      allowedTCPPorts = lib.mkForce (tcpPorts "public");
      allowedUDPPorts = udpPorts "public";
    };
    homelab.services.ssh = {
      port = 22;
      expose = "tailnet";
    };
    services.openssh.openFirewall = false;
    services.avahi.openFirewall = false;
  };

}
