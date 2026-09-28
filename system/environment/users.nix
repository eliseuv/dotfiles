{ pkgs, ... }:
{

  users.users = {

    evf = {
      isNormalUser = true;
      # Pinned (to the uid it already has) so units can name evf's user
      # manager and runtime dir at eval time (see wheatley's services/ttyd.nix).
      uid = 1000;
      description = "evf";
      extraGroups = [
        "wheel"
        "networkmanager"
        "libvirtd"
        "dotfiles"
      ];
      linger = true;
      packages = with pkgs; [ ];
    };

  };

  users.groups.dotfiles = {};

  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

}
