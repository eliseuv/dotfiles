# Headless homelab server
{ ... }:
{

  my.host.type = "server";

  my.services = {
    tailscale.enable = true;
    nas.enable = true;
    dotfilesSwitch.enable = true;
  };

  my.secrets = {
    system.enable = true;
    user.enable = true;
  };

  my.home = {
    notes.enable = true;
    remoteAccess.enable = true;
  };

  my.homelab.enable = true;

}
