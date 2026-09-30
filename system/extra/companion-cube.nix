# CompanionCube (Synology) personal share over NFS, on every host that imports
# this. A dedicated shared folder rather than homes/evf: the export has no
# squashing, and homes/evf belongs to the DSM user (uid 1026), so it would
# have meant renumbering evf everywhere. This share's root was chowned to
# 1000:100 from a client instead; DSM sees it as an unknown uid, with group
# `users` (gid 100 on both sides) as its only way in.
{ config, lib, ... }:
{

  options.companionCube.address = lib.mkOption {
    type = lib.types.str;
    default = "192.168.0.35";
    description = "The Synology NAS's LAN address (DHCP reservation).";
  };

  config = {

    boot.supportedFilesystems = [ "nfs" ];

    # LAN only, and hosts roam off it: soft with a short timeout turns an
    # unreachable NAS into I/O errors instead of processes hung in D state, at
    # the cost of possibly losing a write interrupted mid-flight. The idle
    # timeout unmounts it so suspend/resume on another network finds it gone.
    fileSystems."/mnt/comp-cube" = {
      device = "${config.companionCube.address}:/volume1/drive";
      fsType = "nfs";
      options = [
        "nfsvers=4.1"
        "soft"
        "timeo=50"
        "retrans=2"
        "_netdev"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=600"
        "x-systemd.mount-timeout=10"
      ];
    };

  };

}
