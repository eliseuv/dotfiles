# Navidrome: music streaming (Subsonic API) from the library on the NAS share.
# Reachable from the tailnet so the phone apps work away from home. Accounts
# are Navidrome's own; the first visit creates the admin.
{ config, ... }:
let
  mediaRoot = config.homelab.media.root;
in
{

  services.navidrome = {
    enable = true;
    settings = {
      Address = "0.0.0.0";
      MusicFolder = "${mediaRoot}/library/music";
    };
  };
  users.users.navidrome.extraGroups = [ "media" ];

  homelab.services.navidrome = {
    port = config.services.navidrome.settings.Port;
    expose = "tailnet";
    dashboard = {
      name = "Navidrome";
      group = "Media";
      order = 8;
      description = "Music streaming";
      icon = "navidrome.png";
      unit = "navidrome.service";
    };
  };

}
