# Facts about the host being configured. The shared layer is part of both the
# NixOS and the Home Manager evaluation, so either side can branch on these;
# hosts set them in hosts/<name>/default.nix.
{ config, lib, ... }:
{

  options.my.host = {

    name = lib.mkOption {
      type = lib.types.str;
      description = "Host name. Set by the flake from the hosts/ directory name.";
    };

    channel = lib.mkOption {
      type = lib.types.enum [
        "unstable"
        "stable"
      ];
      default = "unstable";
      description = "nixpkgs branch the system follows.";
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "evf" ];
      description = "Users that exist and run Home Manager on this host; keys of `my.users`.";
    };

    primaryUser = lib.mkOption {
      type = lib.types.str;
      default = lib.head config.my.host.users;
      defaultText = lib.literalExpression "lib.head config.my.host.users";
      description = "The user that host-wide services run as or on behalf of.";
    };

    stateVersion = lib.mkOption {
      type = lib.types.str;
      default = "24.11";
      description = "Both system.stateVersion and home.stateVersion.";
    };

  };

}
