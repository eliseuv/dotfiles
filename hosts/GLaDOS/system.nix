{ config, ... }:
{

  imports = [ ./netdata.nix ];

  boot.loader.timeout = 2;

  # ttyd and Pluto run code as evf, so only wheatley (their reverse proxy) may
  # reach them, over the tailnet rather than the LAN: the router hands out no
  # fixed addresses, tailnet ones don't move. The source is wheatley's
  # homelab.network.tailnetAddress.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -i tailscale0 -s 100.97.1.97 -p tcp --dport ${toString config.my.services.ttyd.port} -j nixos-fw-accept
    iptables -A nixos-fw -i tailscale0 -s 100.97.1.97 -p tcp --dport ${toString config.my.services.pluto.port} -j nixos-fw-accept
  '';

  # Shared with wheatley, whose nginx hands it to her Pluto as a cookie.
  sops.secrets."pluto/secret".sopsFile = ../../secrets/shared/pluto-GLaDOS.yaml;

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
