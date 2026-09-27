{ pkgs, ... }:
{

  users.users = {

    evf = {
      isNormalUser = true;
      # Matches the DSM user on CompanionCube: its NFS exports don't squash, so
      # file ownership there is by numeric uid. NixOS never renumbers an
      # existing user; changing this takes a manual `usermod -u` per host.
      uid = 1026;
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
