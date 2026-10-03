# CompanionCube (Synology) personal share over NFS, on hosts that enable
# `my.services.nas`. A dedicated shared folder rather than homes/evf: the
# export has no squashing, and homes/evf belongs to the DSM user (uid 1026),
# so it would have meant renumbering evf everywhere. This share's root was chowned to
# 1000:100 from a client instead; DSM sees it as an unknown uid, with group
# `users` (gid 100 on both sides) as its only way in.
#
# Mounted on demand with `nas mount [lan|tailnet]` rather than from fstab:
# systemd-fstab-generator stats every fstab mount point when a switch re-execs
# PID 1, and if that switch has also stopped NetworkManager, the stat on the
# live NFS mount blocks until the generator times out and PID 1 freezes.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.services.nas;

  mountPoint = "/mnt/comp-cube";

  nas = pkgs.writeShellApplication {
    name = "nas";
    text = ''
      usage() {
        echo "usage: nas mount [lan|tailnet] | nas umount" >&2
        exit 1
      }

      case "''${1:-}" in
        mount)
          case "''${2:-lan}" in
            lan) address=${lib.escapeShellArg cfg.address} ;;
            tailnet) address=${lib.escapeShellArg (toString cfg.tailnetAddress)} ;;
            *) usage ;;
          esac
          if [ -z "$address" ]; then
            echo "nas: no tailnet address configured for this host" >&2
            exit 1
          fi
          sudo mkdir -p ${mountPoint}
          # Hosts roam off either network: soft with a short timeout turns an
          # unreachable NAS into I/O errors instead of processes hung in D
          # state, at the cost of possibly losing a write interrupted
          # mid-flight.
          sudo mount -t nfs -o nfsvers=4.1,soft,timeo=50,retrans=2 \
            "$address:/volume1/drive" ${mountPoint}
          ;;
        umount)
          sudo umount ${mountPoint}
          ;;
        *) usage ;;
      esac
    '';
  };
in
{

  config = lib.mkIf cfg.enable {

    boot.supportedFilesystems = [ "nfs" ];

    environment.systemPackages = [ nas ];

  };

}
