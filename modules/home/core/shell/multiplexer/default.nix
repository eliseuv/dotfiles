# Which multiplexer interactive SSH logins attach to (the hook is in zsh.nix).
# Chosen here rather than per host, so declared here and not in the shared
# layer; a host's home.nix can still override it.
{ lib, ... }:
{

  options.my.home.multiplexer = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.enum [
        "tmux"
        "zellij"
      ]
    );
    default = "tmux";
    description = "Multiplexer to auto-attach on interactive SSH logins; null for none.";
  };

}
