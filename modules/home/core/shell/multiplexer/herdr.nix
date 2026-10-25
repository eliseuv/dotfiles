# Agent multiplexer, installed for evf only: modules/home applies to every
# user of a host, and dani does not use it.
{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf (config.home.username == "evf") {
    home.packages = [ pkgs.herdr ];
    home.shellAliases.h = "herdr";
  };

}
