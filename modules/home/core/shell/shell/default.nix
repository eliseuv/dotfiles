# Which shell interactive zsh hands over to (the hook is in zsh.nix). zsh stays
# the login shell and $SHELL either way: ssh commands, services and coding
# agents run POSIX through it. Declared here and not in the shared layer, as
# the multiplexer is.
{ config, lib, ... }:
{

  options.my.home.shell = lib.mkOption {
    type = lib.types.enum [
      "zsh"
      "nushell"
    ];
    default = if config.home.username == "evf" then "nushell" else "zsh";
    defaultText = lib.literalExpression ''if config.home.username == "evf" then "nushell" else "zsh"'';
    description = "Interactive shell, until `shell-toggle` overrides it on a machine.";
  };

}
