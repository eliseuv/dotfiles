{ config, lib, ... }:
{

  users.users = lib.genAttrs config.my.host.users (
    name:
    let
      user = config.my.users.${name};
    in
    {
      isNormalUser = true;
      inherit (user) description;
      extraGroups = [
        "wheel"
        "networkmanager"
        "libvirtd"
        "dotfiles"
      ];
    }
    // lib.optionalAttrs (user.uid != null) { inherit (user) uid; }
    // lib.optionalAttrs user.linger { linger = true; }
  );

  users.groups.dotfiles = { };

  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

}
