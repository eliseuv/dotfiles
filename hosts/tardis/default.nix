# Laptop
{ ... }:
{

  my.host.type = "laptop";

  my.desktop = {
    hyprland.enable = true;
    gnome.enable = true;
    monitors = [
      {
        output = "eDP-1";
        mode = "1920x1080@60";
        position = "0x0";
      }
    ];
  };

  my.services = {
    tailscale.enable = true;
    nas = {
      enable = true;
      # Also mount the NAS over the tailnet, for use away from home
      tailnetAddress = "100.109.162.27";
    };
  };

  my.secrets.user.enable = true;

  my.home = {
    apps.enable = true;
    notes.enable = true;
  };

}
