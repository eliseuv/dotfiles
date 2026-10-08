# Jellyfin: plain HTTP on the LAN, HTTPS over the tailnet via Tailscale serve.
{ config, lib, ... }:
let
  jellyfinTailnetPort = 8920;
in
{

  services.jellyfin.enable = true;
  users.users.jellyfin.extraGroups = [ "media" ];

  # Fixed in Jellyfin's own network settings; the module has no option for it.
  homelab.services.jellyfin = {
    port = 8096;
    dashboard = {
      name = "Jellyfin";
      group = "Media";
      order = 1;
      description = "Media server";
      icon = "jellyfin.png";
      widget = {
        type = "jellyfin";
        # Jellyfin 12 dropped the legacy /emby route prefix that the v1 widget
        # calls; v2 uses the plain paths and header auth.
        version = 2;
        enableBlocks = true;
      };
      widgetKey = "jellyfin/api-key";
      unit = "jellyfin.service";
    };
  };
  # Client discovery.
  networking.firewall.lan.allowedUDPPorts = [ 1900 7359 ];

  # HTTPS with a real certificate for tailnet clients. Node serve rather than
  # services.tailscale.serve, which drives Tailscale Services and so needs a
  # tagged node. 8920 is Jellyfin's conventional HTTPS port and leaves 443
  # free. Serve config persists in tailscaled's state, so this re-asserts it
  # on every boot and removes it when the unit goes away.
  systemd.services.jellyfin-tailscale-serve =
    let
      tailscale = lib.getExe config.services.tailscale.package;
    in
    {
      description = "Serve Jellyfin over HTTPS on the tailnet";
      after = [ "tailscaled.service" "jellyfin.service" ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${tailscale} serve --bg --https=${toString jellyfinTailnetPort} http://127.0.0.1:${toString config.homelab.services.jellyfin.port}";
        ExecStop = "${tailscale} serve --https=${toString jellyfinTailnetPort} off";
      };
    };

}
