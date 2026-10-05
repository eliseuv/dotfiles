# Headless homelab server
{ ... }:
{

  my.host.type = "server";

  my.services = {
    # Up at boot: the dashboard and everything it proxies are reached over
    # the tailnet.
    tailscale = {
      enable = true;
      upAtBoot = true;
    };
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
