# Hosts that can be woken with a Wake-on-LAN magic packet. A fleet-wide table
# rather than a per-host option: `wake` on every host needs every target's
# MAC. Being listed here is also what arms WoL on a host's own NIC
# (nixos/core/network.nix). MACs aren't secret: every frame on the LAN
# carries them, and they're useless from outside it.
{ lib, ... }:
{

  options.my.wakeOnLan = {

    hosts = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        GLaDOS = "b4:2e:99:6e:1a:1e";
        wheatley = "20:47:47:08:7c:bd";
      };
      description = "Host name (as in hosts/) -> MAC of the wired NIC that listens for the magic packet.";
    };

    relay = lib.mkOption {
      type = lib.types.str;
      default = "wheatley";
      description = ''
        Always-on LAN host that `wake` asks over the tailnet when run away
        from the LAN, since a magic packet is a LAN broadcast that Tailscale
        can't carry.
      '';
    };

  };

}
