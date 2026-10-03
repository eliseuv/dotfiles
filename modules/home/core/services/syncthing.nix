{ config, lib, ... }:
let
  hostName = config.my.host.name;

  # Hosts by host name, plus devices outside this repository
  deviceIds = {
    A56 = "73TB3JF-EE6S5NA-L6GG3C5-HCD3IP2-CK2KEJ4-D4XYTFV-SV2QEEF-AGRJUQM";
    GLaDOS = "UX6PZ74-S4VYOHG-ZWPX2ME-2ONFFNN-GWWRYCJ-4S7ZIGW-P3Z3ITG-WWELFAV";
    tardis = "NR7XLUG-MNAFRJS-IKP3EGN-TBHXJMW-YGMDSES-MLPOKYD-I5PJ23K-J7AJZQE";
    wheatley = "UY2GE7S-3IADOE6-WWDQKJD-72P5G2A-RPIBVSR-KXVKZWT-D45T4Y3-PRVB3QW";
  };

  # Each folder once, with every device that shares it. A host gets the
  # folders it is a member of, shared with the other members it knows an ID
  # for (chell has none yet, so GLaDOS shares `home` with no one).
  folders = {
    home = {
      path = "~/Documents/home";
      members = [
        "GLaDOS"
        "chell"
      ];
    };
    music = {
      path = "/run/media/evf/Storage/CompanionCube/music";
      members = [
        "GLaDOS"
        "A56"
      ];
    };
    org = {
      path = "~/Documents/org";
      members = [
        "GLaDOS"
        "tardis"
      ];
      versioning = {
        type = "simple";
        params.keep = "8";
      };
    };
    obsidian = {
      path = "~/Documents/obsidian";
      members = [
        "GLaDOS"
        "tardis"
        "A56"
      ];
    };
    notes = {
      path = "~/Documents/notes";
      members = [
        "GLaDOS"
        "tardis"
        "A56"
        "wheatley"
      ];
    };
  };
in
{

  services.syncthing = {

    enable = true;

    extraOptions = [ "--allow-newer-config" ];

    settings = {

      gui = {
        theme = "black";
      };

      devices = lib.mapAttrs (_: id: { inherit id; }) deviceIds;

      folders = lib.mapAttrs (
        _: folder:
        {
          inherit (folder) path;
          devices = lib.filter (device: device != hostName && deviceIds ? ${device}) folder.members;
        }
        // lib.optionalAttrs (folder ? versioning) { inherit (folder) versioning; }
      ) (lib.filterAttrs (_: folder: lib.elem hostName folder.members) folders);

    };
  };

}
