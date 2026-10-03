# Media stack: qBittorrent (download client) -> Sonarr/Radarr (library
# management) <- Prowlarr (indexers) -> Jellyfin (playback) <- Seerr (requests).
# All native NixOS services, open on the LAN and, for Seerr and Jellyfin (over
# HTTPS), the tailnet (see firewall.nix) - Tailscale is the remote-access
# layer, there is no reverse proxy. Downloads and library share one NFS mount
# (nas.nix) so Sonarr/Radarr imports are hardlinks, not cross-device copies;
# service state (SQLite) stays on local disk under /var/lib.
#
# This file holds what the stack shares: the media group, the directory
# layout on the share, and the NAS dependency. Each service has its own file.
{ config, lib, ... }:
let
  mediaRoot = config.homelab.media.root;
  # Units that write to the share.
  mediaServices = [ "qbittorrent" "sonarr" "radarr" "jellyfin" ];
in
{

  imports = [
    ./qbittorrent.nix
    ./arrs.nix
    ./arr-sync.nix
    ./jellyfin.nix
    ./seerr.nix
  ];

  options.homelab.media.root = lib.mkOption {
    type = lib.types.str;
    default = "/mnt/media";
    readOnly = true;
    description = "NFS share holding both downloads and the library (see nas.nix).";
  };

  config = {

    # Pinned: NFS passes numeric IDs through, so this must stay stable for
    # ownership on the NAS to keep meaning the same group.
    users.groups.media.gid = 982;
    users.users.${config.my.host.primaryUser}.extraGroups = [ "media" ];

    systemd.services = lib.mkMerge [
      # Not tmpfiles: systemd-tmpfiles-setup runs before the network is up and
      # would stall on the automount. The share root is included because a
      # fresh Synology shared folder carries only a DSM ACL, which NFS exposes
      # as 000.
      {
        media-dirs = {
          description = "Create media directories on the NAS share";
          unitConfig.RequiresMountsFor = mediaRoot;
          serviceConfig.Type = "oneshot";
          serviceConfig.RemainAfterExit = true;
          script = ''
            install -d -m 2775 -o root -g media \
              ${mediaRoot} ${mediaRoot}/downloads ${mediaRoot}/library/tv ${mediaRoot}/library/movies \
              ${mediaRoot}/library/anime
          '';
        };
      }
      # Hard dependency: if the NAS is down these must not start and write into
      # the bare mountpoint on the root filesystem.
      (lib.genAttrs mediaServices (_: {
        requires = [ "media-dirs.service" ];
        after = [ "media-dirs.service" ];
        unitConfig.RequiresMountsFor = mediaRoot;
      }))
    ];

  };

}
