{ pkgs, ... }:
{

  users.users = {

    evf = {
      isNormalUser = true;
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
