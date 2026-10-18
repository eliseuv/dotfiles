{ ... }:
{

  imports = [ ./netdata.nix ];

  boot.loader.timeout = 2;

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
