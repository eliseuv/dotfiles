{ config, lib, ... }:
{

  options.my.dotfiles = {

    path = lib.mkOption {
      type = lib.types.str;
      default = "/home/${config.my.host.primaryUser}/dotfiles";
      defaultText = lib.literalExpression ''"/home/''${config.my.host.primaryUser}/dotfiles"'';
      description = "Location of the dotfiles repository on this machine.";
    };

    shared = lib.mkEnableOption "group access to the dotfiles repository for every user in the `dotfiles` group (core/dotfiles.nix)";

  };

}
