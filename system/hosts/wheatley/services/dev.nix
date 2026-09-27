# Development tools that run as evf rather than as system services - ttyd is
# a home-manager user service (home/extra/ttyd.nix), the rest are ad-hoc dev
# servers - so only their ports are declared here.
{ ... }:
{

  homelab.services = {
    terminal = {
      port = 3000;
      expose = "tailnet";
      dashboard = {
        name = "Terminal";
        group = "Dev";
        order = 1;
        description = "ttyd web terminal";
        icon = "mdi-console";
      };
    };
    vite = {
      port = 5173;
      dashboard = {
        name = "Vite";
        group = "Dev";
        order = 2;
        description = "Vite dev server";
        icon = "mdi-lightning-bolt";
      };
    };
    # Vite's next choice when 5173 is taken.
    vite-fallback.port = 5174;
    zola.port = 1111;
  };

}
