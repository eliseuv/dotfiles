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
    # Its tailnet address is in system.nix
    nas.enable = true;
  };

  my.secrets.user.enable = true;

  my.home = {
    apps.enable = true;
    notes.enable = true;
    aven.enable = true;
  };

}
