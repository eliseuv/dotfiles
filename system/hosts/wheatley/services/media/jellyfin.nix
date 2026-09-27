# Jellyfin: plain HTTP on the LAN, HTTPS over the tailnet via Tailscale serve.
{ config, lib, ... }:
let
  jellyfinTailnetPort = 8920;
in
{

  services.jellyfin.enable = true;
  users.users.jellyfin.extraGroups = [ "media" ];

  networking.firewall.lan.allowedTCPPorts = [ 8096 ];
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
        ExecStart = "${tailscale} serve --bg --https=${toString jellyfinTailnetPort} http://127.0.0.1:8096";
        ExecStop = "${tailscale} serve --https=${toString jellyfinTailnetPort} off";
      };
    };

}
