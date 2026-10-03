# Shared family workstation
{ ... }:
{

  my.host.users = [
    "evf"
    "dani"
  ];

  # The dotfiles repository is shared between users on this machine
  my.dotfiles.path = "/etc/dotfiles";

  my.desktop = {
    gnome.enable = true;
    gdmMonitors = ./monitors.xml;
  };

  my.hardware.nvidia.enable = true;

  my.services = {
    containers.enable = true;
    virtualisation.enable = true;
  };

  my.gaming.enable = true;

}
