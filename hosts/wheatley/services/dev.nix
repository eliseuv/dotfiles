# Ad-hoc dev servers run by evf rather than as system services, so only their
# ports are declared here; the Wheatley tile's ports menu links to them
# (system.nix).
{ ... }:
{

  homelab.services = {
    vite.port = 5173;
    # Vite's next choice when 5173 is taken.
    vite-fallback.port = 5174;
    zola.port = 1111;
  };

}
