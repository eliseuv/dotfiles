{ config, lib, ... }:
{

  options.my.dotfiles.path = lib.mkOption {
    type = lib.types.str;
    default = "/home/${config.my.host.primaryUser}/dotfiles";
    defaultText = lib.literalExpression ''"/home/''${config.my.host.primaryUser}/dotfiles"'';
    description = "Location of the dotfiles repository on this machine.";
  };

}
