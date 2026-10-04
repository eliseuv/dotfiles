{ config, ... }:
{

  # ttyd hands out a shell, so only wheatley (its reverse proxy, at its
  # homelab.network.lanAddress) may reach it, not the whole LAN.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -s 192.168.0.62 -p tcp --dport ${toString config.my.services.ttyd.port} -j nixos-fw-accept
  '';

  # Mount disks
  fileSystems = {

    "/run/media/evf/Storage" = {
      device = "/dev/disk/by-uuid/2C22035322032186";
      fsType = "ntfs";
      options = [ "nofail" ];
    };

    "/run/media/evf/Research" = {
      device = "/dev/disk/by-uuid/e29cc859-5e69-4dbc-aefa-445ee3da919f";
      fsType = "ext4";
      options = [ "nofail" ];
    };

  };

}
