# Service registry: each service declares its port and who may reach it once,
# next to its own config. firewall.nix opens ports from it; the dashboard adds
# a `dashboard` sub-option and builds its tiles from it (dashboard/).
# Also the network facts several modules need (values in network.nix).
# Declarations only; the modules that act on them are gated by
# `my.homelab.enable`.
{ config, lib, ... }:
let
  str = description: lib.mkOption { type = lib.types.str; inherit description; };
in
{

  options.homelab.network = {
    lanSubnet = str "LAN IPv4 subnet, CIDR; the firewall's LAN tier.";
    nasAddress = str "The Synology NAS's LAN name, resolved over mDNS.";
    tailnetDomain = str "The tailnet's MagicDNS suffix.";
    tailnet = lib.mkOption {
      type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
      description = "Tailscale IPv4 addresses by machine (hosts/ names, and others'); null for one not yet joined. The router hands out no fixed LAN addresses, so hosts reach each other by these.";
    };
    ports = lib.mkOption {
      description = "Ports of the servers on each host (hosts/ names) that others reach, set once so its firewall and wheatley's dashboard and proxies agree: `dev`, label -> port of its ad-hoc dev servers, opened to the LAN and tailnet and listed in its tile's ports menu; `ttyd` and `pluto`, its my.services ones, proxied by the dashboard.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            dev = lib.mkOption {
              type = lib.types.attrsOf lib.types.port;
              default = { };
            };
            ttyd = lib.mkOption { type = lib.types.port; };
            pluto = lib.mkOption { type = lib.types.port; };
          };
        }
      );
    };
    tailnetAddress = str "This host's Tailscale IPv4 address." // {
      default = config.homelab.network.tailnet.${config.my.host.name};
    };
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
