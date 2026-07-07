{ ... }:
{

  # GNOME Display Manager (GDM)
  # Monitor layout comes from environment.etc."xdg/monitors.xml", set per host
  # from ./monitors/<host>.xml.
  services.displayManager.gdm = {
    enable = true;
    autoSuspend = false;
  };

}
