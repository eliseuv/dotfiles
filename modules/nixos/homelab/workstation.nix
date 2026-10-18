# This host's ports from `homelab.network.ports` (network.nix), the table
# wheatley's dashboard also reads for the host's tile and proxies; and, with
# `my.homelab.workstation.enable`, the firewall of a desktop it fronts
# (GLaDOS, chell).
#
# ttyd and Pluto run code as the primary user, so only wheatley (their reverse
# proxy) may reach them, over the tailnet rather than the LAN: the router
# hands out no fixed addresses, tailnet ones don't move. The dev ports are
# open to the whole LAN and tailnet; as in firewall.nix, the LAN is matched on
# source address rather than interface, so inbound IPv6 on the LAN NIC isn't
# admitted.
{ config, lib, ... }:
let
  network = config.homelab.network;
  ports = network.ports.${config.my.host.name} or null;
  accept = match: port: ''
    iptables -A nixos-fw ${match} -p tcp --dport ${toString port} -j nixos-fw-accept
  '';
in
{

  config = lib.mkMerge [

    (lib.mkIf (ports != null) {
      my.services.ttyd.port = ports.ttyd;
      my.services.pluto.port = ports.pluto;
    })

    (lib.mkIf config.my.homelab.workstation.enable {
      assertions = [
        {
          assertion = ports != null;
          message = "my.homelab.workstation needs an entry for ${config.my.host.name} in homelab.network.ports";
        }
      ];
      networking.firewall.extraCommands = lib.concatStrings (
        map (accept "-i tailscale0 -s ${network.tailnet.wheatley}") [
          ports.ttyd
          ports.pluto
        ]
        ++ lib.concatMap (port: [
          (accept "-s ${network.lanSubnet}" port)
          (accept "-i tailscale0" port)
        ]) (lib.attrValues ports.dev)
      );
    })

  ];

}
