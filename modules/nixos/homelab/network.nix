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
    ports =
      let
        # 8080, zola serve and vite.
        desktopDev = {
          HTTP = 8080;
          Zola = 1111;
          Vite = 5173;
        };
      in
      {
        wheatley = {
          dev = {
            Vite = 5173;
            # Vite's next choice when 5173 is taken.
            "Vite (fallback)" = 5174;
            Zola = 1111;
          };
          ttyd = 3000;
          pluto = 1234;
        };
        GLaDOS = {
          dev = desktopDev;
          ttyd = 3000;
          pluto = 1234;
        };
        chell = {
          dev = desktopDev;
          ttyd = 3000;
          pluto = 1234;
        };
      };
  };

}
