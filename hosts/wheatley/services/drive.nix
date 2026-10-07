# Remote access to the NAS's personal-files share (nas.nix) as a web file
# manager - upload, download, share links - for use over the tailnet like a
# cloud drive. File Browser serves the files as they are, so they stay
# ordinary files on the share; there is no sync client.
{ config, lib, ... }:
let
  driveRoot = "/mnt/drive";
in
{

  services.filebrowser = {
    enable = true;
    group = "drive";
    settings = {
      address = "0.0.0.0";
      # qBittorrent has 8080.
      port = 8081;
      root = driveRoot;
    };
  };

  # Pinned like `media`: NFS passes numeric IDs through, so files written here
  # keep meaning the same group on the NAS. A share-specific group keeps this
  # service away from the media library.
  users.groups.drive.gid = 983;
  users.users.${config.my.host.primaryUser}.extraGroups = [ "drive" ];

  systemd.services.filebrowser = {
    # Group-writable so the primary user (and DSM, via the group) can work on
    # what the web UI creates; the module's default is 0077.
    serviceConfig.UMask = lib.mkForce "0002";
    # Hard dependency: never serve (or write into) the bare mountpoint if the
    # NAS is down.
    unitConfig.RequiresMountsFor = driveRoot;
    requires = [ "drive-dirs.service" ];
    after = [ "drive-dirs.service" ];
  };

  # Not tmpfiles, for the reason given for media-dirs (../nas.nix, media/default.nix):
  # the module's entry for the root would stall boot on the automount.
  systemd.tmpfiles.settings.filebrowser.${driveRoot} = lib.mkForce { };
  systemd.services.drive-dirs = {
    description = "Create the drive directory on the NAS share";
    unitConfig.RequiresMountsFor = driveRoot;
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
    script = ''
      install -d -m 2775 -o root -g drive ${driveRoot}
    '';
  };

  homelab.services.drive = {
    port = config.services.filebrowser.settings.port;
    expose = "tailnet";
    dashboard = {
      name = "Drive";
      group = "Tools";
      description = "Files on Companion Cube";
      icon = "filebrowser.png";
      unit = "filebrowser.service";
    };
  };

}
