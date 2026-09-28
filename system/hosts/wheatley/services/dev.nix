# Ad-hoc dev servers run by evf rather than as system services, so only their
# ports are declared here.
{ ... }:
{

  homelab.services = {
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
