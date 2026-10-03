# Laptop
{ ... }:
{

  my.host.type = "laptop";

  my.desktop = {
    hyprland.enable = true;
    gnome.enable = true;
  };

  my.services = {
    tailscale.enable = true;
    nas = {
      enable = true;
      # Also mount the NAS over the tailnet, for use away from home
      tailnetAddress = "100.109.162.27";
    };
  };

}
