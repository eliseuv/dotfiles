# Old laptop
{ ... }:
{

  my.host.type = "laptop";

  my.desktop = {
    i3.enable = true;
    displayManager = "lightdm";
  };

  my.services.tailscale.enable = true;

}
