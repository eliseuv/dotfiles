# CompanionCube (Synology) shares over NFS. Addressed by its mDNS name, since
# the router has no fixed addresses; the Synology export rule must therefore
# allow the LAN subnet rather than single hosts.
{ config, pkgs, ... }:
let
  nasAddress = config.homelab.network.nasAddress;

  # automount keeps boot from blocking on the NAS; consumers pin the real
  # mount via RequiresMountsFor, so no idle-timeout (it would never fire).
  nfsMount = export: {
    device = "${nasAddress}:${export}";
    fsType = "nfs";
    options = [
      "nfsvers=4.1"
      "_netdev"
      "noauto"
      "x-systemd.automount"
      "x-systemd.mount-timeout=30"
      "x-systemd.requires=nas-route.service"
    ];
  };
in
{

  boot.supportedFilesystems = [ "nfs" ];

  # network-online.target can be reached before the route to the LAN is
  # installed, so the first NFS mount attempt at boot fails with "Network is
  # unreachable" and every unit requiring the mount fails with it. Mounts
  # can't retry, so gate them on the NAS's mDNS name resolving, which needs
  # that route.
  systemd.services.nas-route = {
    description = "Wait for a route to the NAS";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = 60;
    };
    script = ''
      until ${pkgs.getent}/bin/getent ahostsv4 ${nasAddress} >/dev/null 2>&1; do
        sleep 1
      done
    '';
  };

  fileSystems."/mnt/media" = nfsMount "/volume1/media";
  # Game server data; Minecraft world backups live under minecraft/ (restic
  # repo, see services/minecraft.nix).
  fileSystems."/mnt/games" = nfsMount "/volume1/games";

  # Another host, so the tile links its LAN name rather than a port
  # here. DSM's cert is self-signed; Homepage's monitor doesn't verify it.
  homelab.services.companion-cube.dashboard = {
    name = "Companion Cube";
    group = "Hosts";
    order = 1;
    description = "Synology NAS (DSM)";
    # Drawn over with the cube face; the dashboard theme CSS matches this name.
    icon = "synology.png";
    href = "https://${nasAddress}:5001";
    # Wake, restart, power off and Tailscale buttons, over SSH as evf to DSM
    # (see the forced command in the comment below); no terminal or switch.
    wake = "CompanionCube";
    poweroff = true;
    reboot = "CompanionCube";
    tailscale = "CompanionCube";
    address = nasAddress;
    sshUser = "evf";
  };
  # svcctl's SSH to DSM checks this key (taken with ssh-keyscan on first
  # setup; confirm it in DSM's Terminal & SNMP settings if in doubt).
  programs.ssh.knownHosts.${nasAddress}.publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINOviZlK40AoSmdUEQO3yLdzEW4ClhrjFWoEw9MHn8EA";

}
