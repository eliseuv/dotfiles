# Ad-hoc dev servers run by evf rather than as system services, so only their
# ports are registered here, from homelab.network.ports; the Wheatley tile's
# ports menu links to them (system.nix). Remote use included, as on the
# desktops (homelab/workstation.nix).
{ config, lib, ... }:
{

  homelab.services = lib.mapAttrs' (
    label: port:
    lib.nameValuePair "dev ${label}" {
      inherit port;
      expose = "tailnet";
    }
  ) config.homelab.network.ports.wheatley.dev;

}
