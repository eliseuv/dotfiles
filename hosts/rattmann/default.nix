# Old laptop: a head for wheatley. Shows his dashboard full-screen and leaves
# the services to him.
{ ... }:
{

  # No desktop session: the kiosk (system.nix) is the only interface
  my.host.type = "server";

  my.services = {
    tailscale.enable = true;
    dotfilesSwitch.enable = true;
    # For the dashboard's restart button; the tile has no on/off, as WoL
    # brings it back
    remotePowerOff.enable = true;
    # Served through wheatley's dashboard nginx, which proxies this subpath to
    # it (hosts/wheatley/system.nix).
    ttyd = {
      enable = true;
      basePath = "/rattmann/terminal";
    };
  };

  my.secrets.system.enable = true;

  # Its 4510U would build toolchains for minutes on every dashboard switch
  my.home.development.enable = false;

}
