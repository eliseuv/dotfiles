# Service registry: each service declares its port and who may reach it once,
# next to its own config. firewall.nix opens ports from it; the dashboard adds
# a `dashboard` sub-option and builds its tiles from it (services/dashboard).
# Also the network facts several modules need (values in configuration.nix).
{ lib, ... }:
let
  str = description: lib.mkOption { type = lib.types.str; inherit description; };
in
{

  options.homelab.network = {
    lanSubnet = str "LAN IPv4 subnet, CIDR; the firewall's LAN tier.";
    lanAddress = str "This host's LAN address (DHCP reservation).";
    nasAddress = str "The Synology NAS's LAN address (DHCP reservation).";
    tailnetDomain = str "The tailnet's MagicDNS suffix.";
    tailnetAddress = str "This host's Tailscale IPv4 address.";
  };

  options.homelab.services = lib.mkOption {
    default = { };
    description = "Services on this host, keyed by a short name.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          port = lib.mkOption {
            type = lib.types.nullOr lib.types.port;
            default = null;
            description = "Primary TCP port; null for entries with nothing to open.";
          };
          expose = lib.mkOption {
            type = lib.types.enum [ "lan" "tailnet" "public" ];
            default = "lan";
            description = "Who may reach `port`: the LAN, the tailnet (and the LAN), or everyone.";
          };
          udp = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Also open `port` over UDP.";
          };
        };
      }
    );
  };

}
