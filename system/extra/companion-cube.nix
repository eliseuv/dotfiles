# CompanionCube (Synology) home folder over NFS, on every host that imports
# this. The export has no squashing, so access relies on evf's uid matching the
# DSM user's (see environment/users.nix).
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
      device = "${config.companionCube.address}:/volume1/homes/evf";
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
