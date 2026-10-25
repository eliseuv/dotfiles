# Agent multiplexer, installed for evf only: modules/home applies to every
# user of a host, and dani does not use it.
{
  config,
  lib,
  pkgs,
  ...
}:
{

  home.packages = lib.mkIf (config.home.username == "evf") [ pkgs.herdr ];

}
