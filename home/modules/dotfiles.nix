{ lib, config, ... }:
{

  options.dotfiles.path = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/dotfiles";
    description = "Location of the dotfiles repository on this machine.";
  };

}
