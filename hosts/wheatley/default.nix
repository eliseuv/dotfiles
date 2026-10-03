# Headless homelab server
{ ... }:
{

  my.host.type = "server";

  my.services = {
    tailscale.enable = true;
    nas.enable = true;
  };

  my.secrets.system.enable = true;

  my.homelab.enable = true;

}
