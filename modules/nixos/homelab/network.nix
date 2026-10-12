# The network facts of registry.nix's `homelab.network`, set once for every
# host: firewalls, proxies and streams on one host name the others' addresses.
{ ... }:
{

  homelab.network = {
    lanSubnet = "192.168.0.0/24";
    tailnetDomain = "taild628c9.ts.net";
    # `tailscale ip -4` on each; they don't move unless a machine rejoins.
    tailnet = {
      wheatley = "100.97.1.97";
      GLaDOS = "100.110.170.42";
      chell = "100.100.96.14";
      # TODO: fill in once he has joined (`tailscale up`)
      rattmann = null;
      # Not hosts here
      CompanionCube = "100.109.162.27";
    };
  };

}
