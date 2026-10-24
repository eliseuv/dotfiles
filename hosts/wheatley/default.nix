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
    # Central git hub for every host's projects (modules/nixos/services/git-hub.nix)
    gitHub = {
      enable = true;
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAUnmhWDmvCC5BrQtkq84+svdTs/SwYJSQWUntpj6gnf evf@GLaDOS(ssh)"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBR/mgTmHW79dRmr0FCuIwE/oPejHJOtXvhWAQLuF//y evf@tardis(ssh)"
      ];
    };
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
