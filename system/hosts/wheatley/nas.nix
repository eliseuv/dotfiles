# CompanionCube (Synology) media share over NFS. Addressed by IP rather than
# companioncube.local: mDNS resolution at mount time is one more thing that can
# fail, and the Synology export rule is IP-based anyway, so both addresses need
# DHCP reservations regardless.
{ ... }:
{

  boot.supportedFilesystems = [ "nfs" ];

  fileSystems."/mnt/media" = {
    device = "192.168.0.35:/volume1/media";
    fsType = "nfs";
    # automount keeps boot from blocking on the NAS; consumers pin the real
    # mount via RequiresMountsFor, so no idle-timeout (it would never fire).
    options = [
      "nfsvers=4.1"
      "_netdev"
      "noauto"
      "x-systemd.automount"
      "x-systemd.mount-timeout=30"
    ];
  };

  # Another host, so the tile links its fixed LAN address rather than a port
  # here. DSM's cert is self-signed; Homepage's monitor doesn't verify it.
  homelab.services.companion-cube.dashboard = {
    name = "Companion Cube";
    group = "Tools";
    order = 1;
    description = "Synology NAS (DSM)";
    # Drawn over with the cube face; the dashboard theme CSS matches this name.
    icon = "synology.png";
    href = "https://192.168.0.35:5001";
  };

  # Minecraft world backups (restic repo, see services/minecraft.nix).
  fileSystems."/mnt/minecraft" = {
    device = "192.168.0.35:/volume1/minecraft";
    fsType = "nfs";
    options = [
      "nfsvers=4.1"
      "_netdev"
      "noauto"
      "x-systemd.automount"
      "x-systemd.mount-timeout=30"
    ];
  };

}
