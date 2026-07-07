{ lib, ... }:
{

  options.dotfiles.path = lib.mkOption {
    type = lib.types.str;
    default = "/home/evf/dotfiles";
    description = "Location of the dotfiles repository on this machine.";
  };

}
