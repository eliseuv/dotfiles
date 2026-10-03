# Main workstation
{ ... }:
{

  my.desktop = {
    hyprland.enable = true;
    gnome.enable = true;
    gdmMonitors = ./monitors.xml;
  };

  my.hardware.nvidia.enable = true;

  my.services = {
    tailscale.enable = true;
    nas.enable = true;
    containers.enable = true;
    virtualisation.enable = true;
  };

  my.gaming.enable = true;

}
